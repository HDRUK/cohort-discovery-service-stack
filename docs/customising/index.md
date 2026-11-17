# Customising

Everything you're expected to change is in two places:

- **`customisations/`**: files, one folder per service. Edit them in place.
- **Chart values**: settings such as URLs, users and resources, in a values file of your own passed with `-f`. The defaults are in `charts/cohort-discovery/values.yaml`; see [Chart values](../reference/values.md).

Don't change `services/` to customise the stack. The services are configured through files, environment variables and the values, so they can be upgraded without merging.

## What's in `customisations/`

| Path | What | Page |
|---|---|---|
| `api/auth.php` | Sign-in settings: password sign-in is off, so everyone uses single sign-on | [Identity and access](identity-and-access.md#password-sign-in) |
| `api/claimsaccesscontrol.php` | How Keycloak groups and roles become the app's workgroups and roles | [Identity and access](identity-and-access.md#map-keycloak-names-to-the-app) |
| `api/workgroups.php` | The workgroups the app has | [Identity and access](identity-and-access.md#workgroups) |
| `keycloak/realm.json` | The Keycloak realm's client and settings | [Identity and access](identity-and-access.md#the-realm) |
| `keycloak/theme/` | The look of the Keycloak sign-in page | [Branding](branding.md#keycloak-sign-in-page) |
| `web/branding/` | The web app's name, text, colours, logo and legal pages | [Branding](branding.md) |
| `provision.json` | The custodians, collection hosts and collections to create, and which are synthetic | [Collections](collections.md) |
| `athena/` | An Athena vocabulary download, git-ignored, to import the full OMOP vocabulary | [Vocabulary](vocabulary.md) |
| `nlp/rules.json`, `nlp/mappings.json` | How the NLP reads free-text queries | [NLP rules](nlp.md) |

You can delete any file you don't want to change. The service then uses its own default:

| Without | The service |
|---|---|
| `api/auth.php` | Offers password sign-in again |
| `api/claimsaccesscontrol.php` | Syncs workgroups only on a user's first sign-in and never removes them, so Keycloak no longer decides access |
| `api/workgroups.php` | Seeds the API's own nine workgroups |
| `nlp/*.json` | Uses its own copy, identical at the pinned release |
| `provision.json` | Creates no collections |
| `keycloak/realm.json` | Fails to install while Keycloak is on, with a message saying so |
| `web/branding/` files | Falls back to the web's own file for each one left out |

## How a change takes effect

| You change | Under Tilt | With Helm |
|---|---|---|
| `web/branding/` | The web image rebuilds | Rebuild and push the web image, then `helm upgrade` with its new tag |
| `api/*.php` | The API, queue and `api-init` restart | `scripts/customisations-values.sh`, then `helm upgrade`. The pods restart by themselves |
| `nlp/*.json` | The NLP restarts | As above |
| `keycloak/theme/` | Keycloak restarts | As above |
| `keycloak/realm.json`, or `keycloak.users`, `groups` or `roles` | **Nothing changes until Keycloak re-imports the realm**, which needs its volume deleted | The same. See [Re-import the realm](identity-and-access.md#re-import-the-realm) |
| `provision.json` | The provision Job runs again | As above. It only adds; it never deletes or renames |
| `athena/` | The `vocab-import` Job runs | Pass `vocab.athena.hostPath`. See [Vocabulary](vocabulary.md) |
| Other chart values | Edit `charts/cohort-discovery/values.yaml`; Tilt redeploys | `helm upgrade -f my-values.yaml …` |

Under Tilt, a few values are set by the Tiltfile and override any values file: `api.appUrl`, `web.appUrl`, `keycloak.enabled`, `keycloak.port`, `provision.enabled` and `vocab.athena.hostPath`. Change them through the `CDS_*` environment variables in [Getting started](../getting-started.md#host-ports).

## Common tasks

| To | See |
|---|---|
| Add a user | [Identity and access](identity-and-access.md#add-a-user) |
| Give a group of users access to a collection | [Identity and access](identity-and-access.md#add-a-group-that-grants-a-workgroup) |
| Rebrand the web app and sign-in page | [Branding](branding.md) |
| Add or change collections | [Collections](collections.md) |
| Search the full OMOP vocabulary | [Vocabulary](vocabulary.md) |
| Teach the NLP a new phrase | [NLP rules](nlp.md) |
