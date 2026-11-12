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

WEB_HOST_PORT = str(int(os.getenv('CDS_WEB_PORT', '3000')))
API_HOST_PORT = str(int(os.getenv('CDS_API_PORT', '8100')))
NLP_HOST_PORT = str(int(os.getenv('CDS_NLP_PORT', '5001')))
API_HOST_URL = 'http://localhost:' + API_HOST_PORT

if not os.getenv('GITHUB_TOKEN', ''):
    fail('GITHUB_TOKEN is not set. The API image needs it to install the private hdruk/* composer packages (until A1). Run: export GITHUB_TOKEN=$(gh auth token)')

local('scripts/local-secrets.sh', quiet=True)
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

docker_build(
    'ghcr.io/hdruk/cohort-discovery-web',
    'services/web',
    build_args={
        'APPLICATION_MODE': 'standalone',
        'API_BASE_URL': API_HOST_URL,
        'NEXT_PUBLIC_TASK_URL': API_HOST_URL + '/api/v1',
        'NEXT_PUBLIC_USE_EXAMPLE_QUERY': 'false',
        'NEXT_PUBLIC_USE_DEBUG_LOGS': 'false',
    },
)

k8s_yaml(helm(
    'charts/cohort-discovery',
    name=RELEASE,
    namespace=NAMESPACE,
    values=[SECRETS_VALUES],
    set=['api.appUrl=' + API_HOST_URL],
))

k8s_resource('cohort-discovery-mysql', new_name='mysql', labels=['data'])
k8s_resource('cohort-discovery-redis', new_name='redis', labels=['data'])
k8s_resource(
    'cohort-discovery-api-init',
    new_name='api-init',
    labels=['init'],
    resource_deps=['mysql', 'redis'],
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
