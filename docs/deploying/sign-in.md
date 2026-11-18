# Sign-in

The stack supports three ways for people to sign in. Choose one before you install, because it decides which secrets you need and whether the provision Job can run.

| | Bundled Keycloak | Your own OIDC provider | Passwords only |
|---|---|---|---|
| Good for | Trials with fictional users | A real service | A quick test with only the admin |
| Values | `keycloak.enabled: true` (the default) | `keycloak.enabled: false`, `sso.issuer`, `sso.clientId` | `keycloak.enabled: false`, `sso.issuer` empty |
| Secrets | `keycloak-admin-password`, `keycloak-client-secret`, `keycloak-user-<passwordKey in kebab case>` for each user | `sso-client-secret` | None beyond `admin-password` |
| Who decides access | Keycloak's groups and roles | Your provider's groups and roles | The app |
| Provision Job | Works | Works only if the provider is a Keycloak; otherwise set `provision.enabled: false` | Set `provision.enabled: false` |

With either single sign-on option, the API replaces each user's roles, custodians and workgroups with what the ID token says on every sign-in, through [the claims mapping](../customising/identity-and-access.md#map-keycloak-names-to-the-app). The service docs explain [the sign-in flow and what a provider must support](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/identity-provider/), and the [SSO settings](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/reference/sso-environment-variables/) the chart sets for you.

## Bundled Keycloak

The chart runs Keycloak with the realm `cohort-discovery-service`, imported from `customisations/keycloak/realm.json`, plus the roles, groups and users in `keycloak.*`, and wires the API to it.

| Value | What |
|---|---|
| `keycloak.url` | Keycloak's URL as the browser sees it, such as `https://auth.cds.example.org`. The API must reach it at the same URL; see [URLs and ingress](services.md#urls-and-ingress) |
| `keycloak.users`, `keycloak.groups`, `keycloak.roles`, `keycloak.defaultGroup` | Who exists and what they're in. See [Identity and access](../customising/identity-and-access.md) |
| `keycloak.themeFiles` | The sign-in page's look, from `customisations/keycloak/theme/`. See [Branding](../customising/branding.md#keycloak-sign-in-page) |
| `keycloak.storageSize`, `keycloak.storageClassName`, `keycloak.resources` | Its volume and resources |

The provision Job signs in as `bootstrap.adminEmail` with that user's Keycloak password, so the admin must be in `keycloak.users`; the chart refuses to install otherwise.

It runs in Keycloak's development mode (`start-dev`), so it's for trials only. Changes to the realm on an existing volume need a [re-import](../customising/identity-and-access.md#re-import-the-realm).

## Your own OIDC provider

For real users, use your organisation's identity provider:

```yaml
keycloak:
  enabled: false
sso:
  issuer: https://login.example.org/realms/research
  clientId: cohort-discovery
```

Put the client's secret in `sso-client-secret`. Then, in the provider:

- register `<api.appUrl>/api/auth/sso/default/callback` as the redirect URI, and `<web.appUrl>/login` as the post-logout redirect;
- send `groups` and `roles` claims in the ID token, and match their values in `customisations/api/claimsaccesscontrol.php` ([the claims mapping](../customising/identity-and-access.md#map-keycloak-names-to-the-app));
- create `bootstrap.adminEmail` as a user, with a verified email, so the admin `api-init` creates can sign in.

The API must reach the issuer URL from inside the cluster. Only some providers work today; see the service docs' [known limitations](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/limitations/), and [when a login fails](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/reference/login-errors/) for what each error means.

The provision Job signs in by filling in Keycloak's login form, as `bootstrap.adminEmail` with `admin-password`. It works only if your provider is a Keycloak where that user has that password and nothing else on the form, such as multi-factor sign-in or a required action. Otherwise set `provision.enabled: false` and [create collections in the app](connect-a-collection.md).

## Passwords only

With `keycloak.enabled: false` and no `sso.issuer`, there's no single sign-on. The login page offers email and password, and the account to start with is the admin `api-init` creates: `bootstrap.adminEmail`, with the `admin-password` secret. Set `provision.enabled: false`: the chart refuses to install with provisioning on and no single sign-on. Use this to check an install works, not to run a service.

## Password sign-in

The stack's `customisations/api/auth.php` turns password sign-in off, so with single sign-on on, the login page offers only single sign-on and the API refuses password sign-in. To offer both, set `password_login.enabled` to `true` in that file; the admin's password is then `admin-password`. Without the file (if you don't pass `api.authPhp`), the API's own default applies and both are offered. With single sign-on off, password sign-in is always offered, whatever the file says.
