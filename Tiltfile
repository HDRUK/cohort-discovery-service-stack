LOCAL_CONTEXTS = [
    'rancher-desktop',
    'docker-desktop',
    'orbstack',
    'minikube',
    'kind-cohort-discovery',
    'k3d-cohort-discovery',
]

if k8s_context() not in LOCAL_CONTEXTS:
    fail('Refusing to run against context "%s". Switch to a local cluster: %s' % (k8s_context(), ', '.join(LOCAL_CONTEXTS)))

allow_k8s_contexts(k8s_context())

RELEASE = 'cohort-discovery'
NAMESPACE = 'cohort-discovery'
SECRETS_VALUES = 'generated/secrets.values.yaml'
CUSTOMISATIONS_VALUES = 'generated/customisations.values.yaml'
CHART_CUSTOMISATIONS = ['customisations/api', 'customisations/keycloak', 'customisations/nlp']

WEB_HOST_PORT = str(int(os.getenv('CDS_WEB_PORT', '3000')))
API_HOST_PORT = str(int(os.getenv('CDS_API_PORT', '8100')))
NLP_HOST_PORT = str(int(os.getenv('CDS_NLP_PORT', '5001')))
KEYCLOAK_HOST_PORT = str(int(os.getenv('CDS_KEYCLOAK_PORT', '8180')))
KEYCLOAK_ENABLED = os.getenv('CDS_KEYCLOAK_ENABLED', 'true') != 'false'
API_HOST_URL = 'http://localhost:' + API_HOST_PORT
WEB_HOST_URL = 'http://localhost:' + WEB_HOST_PORT

if not os.getenv('GITHUB_TOKEN', ''):
    fail('GITHUB_TOKEN is not set. The API image needs it to install the private hdruk/* composer packages (until A1). Run: export GITHUB_TOKEN=$(gh auth token)')

local('scripts/local-secrets.sh', quiet=True)
local('scripts/customisations-values.sh', quiet=True)
for path in CHART_CUSTOMISATIONS + ['customisations/web/branding/assets/logo.svg', 'customisations/web/branding/assets/icon.svg', 'customisations/provision.json', 'scripts/customisations-values.sh']:
    watch_file(path)
local(
    'kubectl --context "$CONTEXT" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --context "$CONTEXT" apply -f -',
    quiet=True,
    env={'CONTEXT': k8s_context(), 'NAMESPACE': NAMESPACE},
)

docker_build(
    'ghcr.io/hdruk/cohort-discovery-api',
    'services/api',
    secret=['id=github_token,env=GITHUB_TOKEN'],
)

docker_build(
    'ghcr.io/hdruk/cohort-discovery-nlp',
    'services/nlp',
)

WEB_BUILD_ARGS = {
    'APPLICATION_MODE': 'standalone',
    'API_BASE_URL': API_HOST_URL,
    'NEXT_PUBLIC_TASK_URL': API_HOST_URL + '/api/v1',
    'NEXT_PUBLIC_USE_EXAMPLE_QUERY': 'false',
    'NEXT_PUBLIC_USE_DEBUG_LOGS': 'false',
}

custom_build(
    'ghcr.io/hdruk/cohort-discovery-web',
    'scripts/build-web.sh "$EXPECTED_REF" ' + ' '.join([
        '--build-arg %s=%s' % (name, shlex.quote(value))
        for name, value in WEB_BUILD_ARGS.items()
    ]),
    deps=['services/web', 'customisations/web/branding', 'scripts/build-web.sh'],
    ignore=['services/web/node_modules', 'services/web/.next'],
)

k8s_yaml(helm(
    'charts/cohort-discovery',
    name=RELEASE,
    namespace=NAMESPACE,
    values=[SECRETS_VALUES, CUSTOMISATIONS_VALUES],
    set=[
        'api.appUrl=' + API_HOST_URL,
        'web.appUrl=' + WEB_HOST_URL,
        'keycloak.enabled=' + str(KEYCLOAK_ENABLED).lower(),
        'provision.enabled=' + str(KEYCLOAK_ENABLED).lower(),
        'keycloak.port=' + KEYCLOAK_HOST_PORT,
    ],
))

k8s_resource('cohort-discovery-mysql', new_name='mysql', labels=['data'])
k8s_resource('cohort-discovery-redis', new_name='redis', labels=['data'])
if KEYCLOAK_ENABLED:
    k8s_resource(
        'cohort-discovery-keycloak',
        new_name='keycloak',
        labels=['auth'],
        port_forwards=[KEYCLOAK_HOST_PORT + ':' + KEYCLOAK_HOST_PORT],
    )
k8s_resource(
    'cohort-discovery-api-init',
    new_name='api-init',
    labels=['init'],
    resource_deps=['mysql', 'redis'],
)
if KEYCLOAK_ENABLED and os.path.exists('customisations/provision.json'):
    k8s_resource(
        'cohort-discovery-provision',
        new_name='provision',
        labels=['init'],
        resource_deps=['api', 'keycloak'],
    )
k8s_resource(
    'cohort-discovery-api',
    new_name='api',
    labels=['services'],
    resource_deps=['api-init'],
    port_forwards=[API_HOST_PORT + ':8100'],
)
k8s_resource(
    'cohort-discovery-queue',
    new_name='queue',
    labels=['services'],
    resource_deps=['api-init'],
)
k8s_resource(
    'cohort-discovery-nlp',
    new_name='nlp',
    labels=['services'],
    resource_deps=['api-init'],
    port_forwards=[NLP_HOST_PORT + ':5001'],
)
k8s_resource(
    'cohort-discovery-web',
    new_name='web',
    labels=['services'],
    resource_deps=['api'],
    port_forwards=[WEB_HOST_PORT + ':3000'],
)
for scheduled_command in [
    'distributions-collector',
    'task-cleanup-job',
    'collection-no-activity-monitor',
    'collection-task-backlog-monitor',
]:
    k8s_resource(
        'cohort-discovery-' + scheduled_command,
        new_name='scheduler-' + scheduled_command,
        labels=['scheduler'],
        resource_deps=['api'],
    )
