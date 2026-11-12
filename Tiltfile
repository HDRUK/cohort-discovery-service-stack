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

manifests = helm('charts/cohort-discovery', name='cohort-discovery')
if str(manifests).strip():
    k8s_yaml(manifests)
