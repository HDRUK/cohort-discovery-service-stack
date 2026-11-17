import http.cookiejar
import urllib.parse
import pathlib
import sys
import unittest
import urllib.request

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "charts/cohort-discovery/files/provision"))

import provision

COLLECTION = {"id": 7, "pid": "11111111-1111-1111-1111-111111111111", "name": "Synthetic Collection A"}
PLAN = {
    "custodians": [{
        "name": "Demo Custodian",
        "hosts": [{
            "name": "Synthetic Host",
            "collections": [{"name": "Synthetic Collection A", "description": "Synthetic.", "synthetic": True}],
        }],
    }],
}


class FakeApi:
    def __init__(self, configs):
        self.configs = configs
        self.calls = []

    def __call__(self, method, path, body=None):
        self.calls.append((method, path, body))
        if (method, path) == ("GET", "/v1/workgroups"):
            return []
        if (method, path) == ("GET", "/v1/custodians"):
            return [{"id": 1, "pid": "custodian-pid", "name": "Demo Custodian"}]
        if (method, path) == ("GET", "/v1/custodians/custodian-pid/collection_hosts"):
            return [{"id": 2, "name": "Synthetic Host", "collections": [dict(COLLECTION)]}]
        if (method, path) == ("GET", f"/v1/collections/{COLLECTION['id']}"):
            return {**COLLECTION, "workgroups": [], "model_state": {"state": {"slug": "active"}}}
        if (method, path) == ("GET", "/v1/collection_config"):
            return self.configs
        return {}

    def posts_to(self, path):
        return [body for method, called_path, body in self.calls if method == "POST" and called_path == path]


class FakeKube:
    def secret_exists(self, name):
        return True

    def write_secret(self, name, string_data):
        pass

    def restart_deployments(self, label_selector):
        return []


def run(configs):
    api = FakeApi(configs)
    provision.Provisioner(api, FakeKube(), "http://api/api/v1").run(PLAN)
    return api


class DistributionSchedules(unittest.TestCase):
    def test_a_collection_without_schedules_gets_both_and_runs_them_now(self):
        api = run([])

        self.assertEqual(
            sorted(api.posts_to("/v1/collection_config"), key=lambda body: body["type"]),
            [
                {"collection_id": 7, "type": "DEMOGRAPHICS", "frequency_mode": 2, "run_time_frequency": 1,
                 "run_time_hour": 23, "run_time_minute": 59, "enabled": 1},
                {"collection_id": 7, "type": "GENERIC", "frequency_mode": 1, "run_time_frequency": 6,
                 "run_time_hour": 23, "run_time_minute": 59, "enabled": 1},
            ],
        )
        self.assertEqual(
            sorted(body["query_type"] for body in api.posts_to(f"/v1/collection/{COLLECTION['pid']}/distributions/run-manually")),
            ["DEMOGRAPHICS", "GENERIC"],
        )

    def test_a_collection_with_both_schedules_is_left_alone(self):
        api = run([
            {"id": 1, "collection_id": 7, "type": "GENERIC"},
            {"id": 2, "collection_id": 7, "type": "DEMOGRAPHICS"},
        ])

        self.assertEqual(api.posts_to("/v1/collection_config"), [])
        self.assertEqual(api.posts_to(f"/v1/collection/{COLLECTION['pid']}/distributions/run-manually"), [])

    def test_only_the_missing_schedule_is_added_and_run(self):
        api = run([{"id": 1, "collection_id": 7, "type": "GENERIC"}])

        self.assertEqual([body["type"] for body in api.posts_to("/v1/collection_config")], ["DEMOGRAPHICS"])
        self.assertEqual(
            [body["query_type"] for body in api.posts_to(f"/v1/collection/{COLLECTION['pid']}/distributions/run-manually")],
            ["DEMOGRAPHICS"],
        )

    def test_another_collections_schedules_dont_count(self):
        api = run([
            {"id": 1, "collection_id": 99, "type": "GENERIC"},
            {"id": 2, "collection_id": 99, "type": "DEMOGRAPHICS"},
        ])

        self.assertEqual(len(api.posts_to("/v1/collection_config")), 2)



class SecureCookiesOnLocalhost(unittest.TestCase):
    def secure_cookie_sent(self, url):
        cookie = http.cookiejar.Cookie(
            0, "KC_RESTART", "value", None, False, urllib.parse.urlparse(url).hostname, False, False,
            "/", True, True, None, False, None, None, {},
        )
        return provision.LocalhostIsSecureContext().return_ok_secure(cookie, urllib.request.Request(url))

    def test_localhost_and_its_subdomains_are_secure_contexts(self):
        self.assertTrue(self.secure_cookie_sent("http://localhost:8180/realms/x"))
        self.assertTrue(self.secure_cookie_sent("http://auth.cds.localhost/realms/x"))

    def test_other_plain_http_hosts_are_not(self):
        self.assertFalse(self.secure_cookie_sent("http://auth.example.org/realms/x"))
        self.assertFalse(self.secure_cookie_sent("http://notlocalhost/realms/x"))


if __name__ == "__main__":
    unittest.main()
