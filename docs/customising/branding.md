# Branding

The stack ships a neutral brand, "Feasibility Tool", rather than HDR UK's. To use your own, edit `customisations/web/branding/` for the web app and `customisations/keycloak/theme/` for the sign-in page.

## The web app

The web is branded when its image is built, so a change means a rebuild. Tilt rebuilds it when anything in the folder changes; on a cluster, rebuild and push it (see [The web app](../deploying/web.md#build-the-image)).

| File | What |
|---|---|
| `branding.config.ts` | The product's name and description, the sign-in page's title and headlines, the organisation's name and link, the copyright holder, and the legal pages' titles and dates |
| `theme.ts` | Colours and font, merged over the web's own theme. Set `primary` and `secondary`, or the web's default colours show through |
| `assets/logo.svg` | The header logo, shown on the `secondary` colour at 30px high, so it needs light artwork. Also used on the Keycloak sign-in page |
| `assets/icon.svg` | A square version of the logo's mark, used as the Keycloak sign-in page's favicon |
| `legal/termsAndConditions.mdx`, `legal/privacyPolicy.mdx` | Placeholders that say they must be replaced |

`scripts/build-web.sh <image> [docker build options]` copies `services/web` to a temporary folder, copies `customisations/web/branding/` over its `branding/` folder and runs the web's own Dockerfile. Any file you leave out falls back to the web's own, which is HDR UK's.

### `branding.config.ts`

The service docs' [branding page](https://hdruk.github.io/cohort-discovery-service-docs/developers/deploying/branding/) is the full reference for every field, the theme layers and fonts. In short:


| Field | What |
|---|---|
| `productName` | The short name, used in sentences such as "Sign in to your … workspace" |
| `productLongName` | The browser tab's title |
| `description` | The page description search engines show |
| `loginTitle`, `loginHeadline` | The sign-in page's title and headline, each exactly two strings, one per line |
| `loginSubheadline` | The text under the headline |
| `organisationName` | Your organisation's name. The footer link that uses it is hidden in standalone mode |
| `copyrightHolder` | The copyright line on the sign-in page |
| `logoAlt` | The logo's alternative text |
| `links.organisation` | Your organisation's website. Not linked from the footer in standalone mode |
| `links.cookieNotice`, `links.accessibilityStatement` | Footer links. In standalone mode each is hidden unless set |
| `legal.*` | Each legal page's `title` and `lastUpdated` |
| `hdrukChromeInStandalone` | `true` shows the HDR UK header and footer in standalone mode. Leave it `false` |

### Before a real deployment

- Replace both legal pages.
- Set `copyrightHolder`, and `links.cookieNotice` and `links.accessibilityStatement` if you have those pages.

### Known gaps

A few things still come from the web itself rather than `branding/`: the browser-tab favicon, the copyright text and some HDR UK wording on signed-in pages.

## Keycloak sign-in page

`customisations/keycloak/theme/` is a Keycloak login theme, `cohort-discovery`. It extends Keycloak's own `keycloak.v2` theme and restyles it to match the web app, with the logo in place of the realm name. `realm.json` selects it with `"loginTheme": "cohort-discovery"`.

| File | What |
|---|---|
| `login/theme.properties` | The parent theme, the stylesheets and the favicon |
| `login/resources/css/customisations.css` | The colours and layout, mostly as PatternFly variables. Keep the colours in step with `customisations/web/branding/theme.ts` by hand |

The logo and favicon aren't copied into the theme. `scripts/customisations-values.sh` takes `customisations/web/branding/assets/logo.svg` and `icon.svg` and serves them as the theme's `img/logo.svg` and `img/icon.svg`, so the web and Keycloak share one copy.

Any other file you add under `theme/` is mounted at the same path under `/opt/keycloak/themes/cohort-discovery/`. For example, `login/messages/messages_en.properties` changes the page's wording.

Theme changes reach a running Keycloak without a re-import: Keycloak restarts when the files change. Switching the theme on for a realm imported before it existed does need a [re-import](identity-and-access.md#re-import-the-realm), because `loginTheme` is part of `realm.json`. Without the `theme/` folder, Keycloak logs `Failed to find LOGIN theme cohort-discovery` and uses its own look.
