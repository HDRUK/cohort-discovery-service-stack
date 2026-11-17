# Cohort Discovery Service stack

Run the Cohort Discovery Service on your own Kubernetes cluster.

The Cohort Discovery Service lets researchers ask *how many people match these criteria?* across many data collections at once, without seeing any individual's record. Each collection stays with its data custodian; agents beside the data, BUNNYs, run the queries and send back rounded counts.

This stack runs the whole service in **standalone mode**, with its own sign-in through Keycloak, an OMOP vocabulary, and synthetic collections that answer queries straight away. One Helm chart defines it; Tilt drives it on a laptop.

<div class="grid cards" markdown>

-   **1. Understand it**

    The [Overview](overview.md) shows every part on one diagram, how a query flows, and the words the service uses.

-   **2. Run locally**

    [Run the whole stack](getting-started.md) with Tilt, sign in as a fictional researcher and run a query.

-   **3. Make it yours**

    [Customise](customising/index.md) the users and access, branding, collections, vocabulary and NLP rules.

-   **4. Deploy it**

    [Deploy to a cluster](deploying/index.md) with Helm, then [connect custodians' collections](deploying/connect-a-collection.md).

</div>

Something wrong? See the [FAQ](faq.md). Working on the web app? See [Develop the web app](developing/web.md).

These pages cover running **this stack**. The general [Cohort Discovery Service docs](https://hdruk.github.io/cohort-discovery-service-docs/) cover the service itself: BUNNY, identity providers, OMOP requirements and governance. These pages link to them where they're the better reference.

!!! info "Status"
    Usable for local evaluation and development, and installable on a shared cluster with some [known limitations](deploying/index.md#known-limitations). Published images and CI are still to come. The [tracker](https://github.com/HDRUK/cohort-discovery-service-stack/blob/main/docs/README.md) has the detail.

!!! warning "Personal data"
    The service stores researchers' email addresses, identity-provider claims and activity logs. Read the [personal data inventory](data-protection/personal-data-inventory.md) before running it with real users.
