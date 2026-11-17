# Cohort Discovery Service stack

Run the Cohort Discovery Service on your own Kubernetes cluster.

The Cohort Discovery Service lets researchers ask *how many people match these criteria?* across many data collections at once, without seeing any individual's record. Each collection stays with its data custodian; an agent beside the data, BUNNY, runs the queries and sends back rounded counts.

This stack runs the whole service in **standalone mode**, with its own sign-in through Keycloak, an OMOP vocabulary, and synthetic collections that answer queries straight away. One Helm chart defines it; Tilt drives it on a laptop.

<div class="grid cards" markdown>

-   **New here?**

    Read the [Overview](overview.md) for what each part does, then follow [Getting started](getting-started.md) to run it on your laptop.

-   **Make it yours**

    [Customise](customising/index.md) the users and access, branding, collections, vocabulary and NLP rules.

-   **Run it for real**

    [Install it beyond a laptop](installing/beyond-a-laptop.md), with an ingress, TLS, external databases and your own identity provider.

-   **Something wrong?**

    [Troubleshooting](operations/troubleshooting.md) covers the common failures; [Maintaining](operations/maintaining.md) covers logs, upgrades and backups.

</div>

## Quick start

```bash
git clone --recurse-submodules https://github.com/HDRUK/cohort-discovery-service-stack.git
cd cohort-discovery-service-stack
export GITHUB_TOKEN=$(gh auth token)   # for now, must be able to read HDR UK's private composer packages
tilt up
```

Then open http://localhost:3000 and choose **Single Sign-On**. [Getting started](getting-started.md#sign-in) lists the users and where their passwords are.

!!! info "Status"
    Usable for local evaluation and development. Installing on a shared cluster is in review; published images and CI are still to come. The [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/README.md) has the detail.

!!! warning "Personal data"
    The service stores researchers' email addresses, identity-provider claims and activity logs. Read the [personal data inventory](data-protection/personal-data-inventory.md) before running it with real users.
