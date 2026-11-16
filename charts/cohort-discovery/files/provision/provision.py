import datetime
import html
import http.cookiejar
import json
import os
import re
import socket
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

REDIRECT_STATUSES = {301, 302, 303, 307, 308}
SERVICE_ACCOUNT_DIR = "/var/run/secrets/kubernetes.io/serviceaccount"
BUNNY_HOST_LABEL = "cohort-discovery.hdruk.ac.uk/bunny-host"
WEEKLY = 1
MONTHLY = 2
DISTRIBUTION_SCHEDULES = {
    "GENERIC": {"frequency_mode": WEEKLY, "run_time_frequency": 6},
    "DEMOGRAPHICS": {"frequency_mode": MONTHLY, "run_time_frequency": 1},
}


class ProvisionError(Exception):
    pass


class KeepRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class LocalhostIsSecureContext(http.cookiejar.DefaultCookiePolicy):
    def return_ok_secure(self, cookie, request):
        return urllib.parse.urlparse(request.full_url).hostname == "localhost" or super().return_ok_secure(cookie, request)


def log(message):
    print(f"provision: {message}", flush=True)


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def route_hosts(spec):
    routes = {}
    for entry in filter(None, (part.strip() for part in spec.split(","))):
        source, target = entry.split("=")
        source_host, source_port = source.rsplit(":", 1)
        target_host, target_port = target.rsplit(":", 1)
        routes[(source_host, source_port)] = (target_host, int(target_port))
    system_getaddrinfo = socket.getaddrinfo

    def getaddrinfo(host, port, *args, **kwargs):
        host, port = routes.get((host, str(port)), (host, port))
        return system_getaddrinfo(host, port, *args, **kwargs)

    socket.getaddrinfo = getaddrinfo


def send(opener, method, url, body=None, headers=None):
    request = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with opener.open(request, timeout=30) as response:
            return response.status, response.headers, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.headers, error.read().decode()


def location_of(status, headers, step):
    if status not in REDIRECT_STATUSES or not headers.get("Location"):
        raise ProvisionError(f"sign-in: {step} returned HTTP {status}, not a redirect")
    return headers["Location"]


def sign_in(api_url, username, password):
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar(LocalhostIsSecureContext())), KeepRedirects
    )
    keycloak_url = location_of(*send(opener, "GET", f"{api_url}/api/auth/sso/default/redirect")[:2], "the API's SSO redirect")
    status, _, page = send(opener, "GET", keycloak_url)
    form = re.search(r'<form\b[^>]*\bid="kc-form-login"[^>]*>', page)
    action = form and re.search(r'\baction="([^"]+)"', form.group(0))
    if status != 200 or not action:
        raise ProvisionError(f"sign-in: Keycloak's login page (HTTP {status}) has no login form")
    credentials = urllib.parse.urlencode({"username": username, "password": password}).encode()
    status, headers, _ = send(
        opener, "POST", html.unescape(action.group(1)), credentials,
        {"Content-Type": "application/x-www-form-urlencoded"},
    )
    if status == 200:
        raise ProvisionError(f"sign-in: Keycloak refused the credentials for {username}")
    callback_url = location_of(status, headers, "Keycloak's login form")
    frontend_url = location_of(*send(opener, "GET", callback_url)[:2], "the API's SSO callback")
    query = urllib.parse.parse_qs(urllib.parse.urlparse(frontend_url).query)
    if "code" not in query:
        raise ProvisionError(f"sign-in: the API's SSO callback failed: {query.get('error_code', ['no code'])[0]}")
    status, _, body = send(
        opener, "POST", f"{api_url}/api/auth/sso/exchange",
        json.dumps({"code": query["code"][0]}).encode(),
        {"Content-Type": "application/json", "Accept": "application/json"},
    )
    if status != 200:
        raise ProvisionError(f"sign-in: exchanging the handoff code returned HTTP {status}")
    return json.loads(body)["data"]["access_token"]


class Api:
    def __init__(self, url, token):
        self.url = url
        self.token = token
        self.opener = urllib.request.build_opener()

    def __call__(self, method, path, body=None):
        status, _, text = send(
            self.opener, method, f"{self.url}/api{path}",
            None if body is None else json.dumps(body).encode(),
            {"Authorization": f"Bearer {self.token}", "Accept": "application/json", "Content-Type": "application/json"},
        )
        if status >= 400:
            raise ProvisionError(f"{method} {path} returned HTTP {status}: {text[:500]}")
        return json.loads(text)["data"]


class Kube:
    def __init__(self):
        with open(f"{SERVICE_ACCOUNT_DIR}/namespace") as file:
            namespace = file.read().strip()
        with open(f"{SERVICE_ACCOUNT_DIR}/token") as file:
            self.token = file.read().strip()
        context = ssl.create_default_context(cafile=f"{SERVICE_ACCOUNT_DIR}/ca.crt")
        self.opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=context))
        self.secrets_url = f"https://kubernetes.default.svc/api/v1/namespaces/{namespace}/secrets"
        self.deployments_url = f"https://kubernetes.default.svc/apis/apps/v1/namespaces/{namespace}/deployments"

    def request(self, method, url, body=None, content_type="application/json"):
        status, _, text = send(
            self.opener, method, url,
            None if body is None else json.dumps(body).encode(),
            {"Authorization": f"Bearer {self.token}", "Accept": "application/json", "Content-Type": content_type},
        )
        return status, text

    def secret_exists(self, name):
        status, _ = self.request("GET", f"{self.secrets_url}/{name}")
        if status not in (200, 404):
            raise ProvisionError(f"reading Secret {name} returned HTTP {status}")
        return status == 200

    def write_secret(self, name, string_data):
        status, _ = self.request("POST", self.secrets_url, {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": name}, "stringData": string_data})
        if status == 409:
            status, _ = self.request("PATCH", f"{self.secrets_url}/{name}", {"stringData": string_data}, "application/merge-patch+json")
        if status not in (200, 201):
            raise ProvisionError(f"writing Secret {name} returned HTTP {status}")

    def restart_deployments(self, label_selector):
        status, text = self.request("GET", f"{self.deployments_url}?labelSelector={urllib.parse.quote(label_selector)}")
        if status != 200:
            raise ProvisionError(f"listing Deployments {label_selector} returned HTTP {status}")
        names = [item["metadata"]["name"] for item in json.loads(text)["items"]]
        restarted_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        for name in names:
            status, _ = self.request(
                "PATCH", f"{self.deployments_url}/{name}",
                {"spec": {"template": {"metadata": {"annotations": {"kubectl.kubernetes.io/restartedAt": restarted_at}}}}},
                "application/merge-patch+json",
            )
            if status != 200:
                raise ProvisionError(f"restarting Deployment {name} returned HTTP {status}")
        return names


class Provisioner:
    def __init__(self, api, kube, task_api_url):
        self.api = api
        self.kube = kube
        self.task_api_url = task_api_url
        self.changes = 0

    def changed(self, message):
        self.changes += 1
        log(message)

    def run(self, plan):
        workgroup_ids = {workgroup["name"].upper(): workgroup["id"] for workgroup in self.api("GET", "/v1/workgroups")}
        unknown = sorted({
            name for custodian in plan["custodians"] for host in custodian.get("hosts", [])
            for collection in host.get("collections", []) for name in collection.get("workgroups", [])
            if name.upper() not in workgroup_ids
        })
        if unknown:
            raise ProvisionError(f"unknown workgroups {', '.join(unknown)}; the API has {', '.join(sorted(workgroup_ids))}")
        self.scheduled_types = {}
        for config in self.api("GET", "/v1/collection_config"):
            self.scheduled_types.setdefault(config["collection_id"], set()).add(config["type"])
        custodians = {custodian["name"]: custodian for custodian in self.api("GET", "/v1/custodians")}
        for custodian_plan in plan["custodians"]:
            custodian = custodians.get(custodian_plan["name"]) or self.create_custodian(custodian_plan["name"])
            hosts = {host["name"]: host for host in self.api("GET", f"/v1/custodians/{custodian['pid']}/collection_hosts")}
            for host_plan in custodian_plan.get("hosts", []):
                self.provision_host(custodian, hosts.get(host_plan["name"]), host_plan, workgroup_ids)
        log(f"{self.changes} change(s)" if self.changes else "nothing to change")

    def create_custodian(self, name):
        custodian = self.api("POST", "/v1/custodians", {"name": name})
        self.changed(f"created custodian {name}")
        return custodian

    def provision_host(self, custodian, host, host_plan, workgroup_ids):
        secret_name = f"bunny-{slug(host_plan['name'])}"
        identifiers_changed = host is None
        if host is None:
            host = self.api("POST", "/v1/collection_hosts", {
                "name": host_plan["name"], "query_context_type": "bunny", "custodian_id": custodian["id"],
            })
            self.kube.write_secret(secret_name, {
                "TASK_API_BASE_URL": self.task_api_url,
                "TASK_API_USERNAME": host["client_id"],
                "TASK_API_PASSWORD": host["client_secret"],
            })
            host["collections"] = []
            self.changed(f"created host {host_plan['name']} and Secret {secret_name}")
        elif not self.kube.secret_exists(secret_name):
            raise ProvisionError(
                f"host {host_plan['name']} exists but Secret {secret_name} doesn't, so its BUNNY credentials are lost "
                "and the API can't show them again. Delete the host in the app, or restore the Secret, then run again."
            )
        collection_ids = {}
        for collection_plan in host_plan.get("collections", []):
            collection, created = self.provision_collection(custodian, host, collection_plan, workgroup_ids)
            identifiers_changed = identifiers_changed or created
            collection_ids[f"collection-{slug(collection_plan['name'])}"] = collection["pid"]
        if collection_ids:
            self.kube.write_secret(secret_name, collection_ids)
        if identifiers_changed:
            for name in self.kube.restart_deployments(f"{BUNNY_HOST_LABEL}={slug(host_plan['name'])}"):
                log(f"restarted {name} to pick up Secret {secret_name}")

    def provision_collection(self, custodian, host, collection_plan, workgroup_ids):
        name = collection_plan["name"]
        collection = next((existing for existing in host["collections"] if existing["name"] == name), None)
        created = collection is None
        if created:
            collection = self.api("POST", f"/v1/custodians/{custodian['pid']}/collections", {
                "name": name,
                "description": collection_plan["description"],
                "type": "bunny",
                "host_id": host["id"],
                "is_synthetic": collection_plan.get("synthetic", False),
            })
            self.changed(f"created collection {name}")
        detail = self.api("GET", f"/v1/collections/{collection['id']}")
        current_workgroups = {workgroup["id"] for workgroup in detail.get("workgroups", [])}
        for workgroup in collection_plan.get("workgroups", []):
            if workgroup_ids[workgroup.upper()] not in current_workgroups:
                self.api("POST", f"/v1/collections/{collection['id']}/workgroup", {"workgroup_id": workgroup_ids[workgroup.upper()]})
                self.changed(f"added collection {name} to workgroup {workgroup.upper()}")
        state = ((detail.get("model_state") or {}).get("state") or {}).get("slug")
        if state != "active":
            self.api("PUT", f"/v1/collections/{collection['id']}/transition_to", {"state": "active"})
            self.changed(f"moved collection {name} from {state} to active")
        self.schedule_distributions(detail)
        return detail, created

    def schedule_distributions(self, collection):
        scheduled = self.scheduled_types.get(collection["id"], set())
        for query_type, schedule in DISTRIBUTION_SCHEDULES.items():
            if query_type in scheduled:
                continue
            self.api("POST", "/v1/collection_config", {
                "collection_id": collection["id"], "type": query_type, **schedule,
                "run_time_hour": 23, "run_time_minute": 59, "enabled": 1,
            })
            self.api("POST", f"/v1/collection/{collection['pid']}/distributions/run-manually", {"query_type": query_type})
            self.changed(f"scheduled {query_type} distributions for collection {collection['name']} and ran them now")


def main():
    route_hosts(os.environ.get("ROUTE_HOSTS", ""))
    with open(os.environ["PROVISION_FILE"]) as file:
        plan = json.load(file)
    api_url = os.environ["API_URL"]
    token = sign_in(api_url, os.environ["ADMIN_EMAIL"], os.environ["ADMIN_PASSWORD"])
    Provisioner(Api(api_url, token), Kube(), os.environ["TASK_API_BASE_URL"]).run(plan)


if __name__ == "__main__":
    try:
        main()
    except ProvisionError as error:
        print(f"provision: {error}", file=sys.stderr)
        sys.exit(1)
