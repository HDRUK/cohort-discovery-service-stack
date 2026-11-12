# Personal data inventory

What the Cohort Discovery Service stores, logs or sends about people (researchers, custodians and administrators). It's for the data protection owner to review under UK GDPR. It records facts found in the code and is not legal advice.

Compiled 2026-11-12 for H1, from the API at `v1.17.0` (the version the stack pins), the web and NLP services, and this repo's chart. Items marked ✔ were checked line by line; the rest come from a read-only survey of the code, with file references so they can be checked.

## Needs attention first

1. **✔ Plaintext passwords in the API's logs.** `LogHttpRequests` (`app/Http/Middleware/LogHttpRequests.php`) is global middleware. At INFO level it logs every request's full body, plus the client IP, without redaction. A password sign-in (`POST /api/auth/login`) therefore writes the email and password to the log, and SSO hand-off codes and free text typed for NLP parsing are logged the same way. The stack logs at `info` by default, and HDR UK's environments log at `debug` or `info`.
2. **✔ Request bodies kept indefinitely.** `AuditRequests` stores every request in `request_audits` with the user ID, IP address, user agent and body, removing only `password` and `token`. Nothing deletes these rows, and they're kept when a user is deleted (the user ID is set to null).
3. **✔ Requester email sent to Slack.** The "Collection Activation Request" alert includes the requesting user's email (`app/Services/Notifications/SlackNotifier.php`). The stack doesn't configure a Slack webhook, but HDR UK's deployments may.
4. **✔ No retention is enforced.** `config/activitylog.php` sets 365 days, but nothing schedules `activitylog:clean`, and nothing prunes `request_audits`, `nlp_query_logs` or expired Passport tokens.

## Inventory

| Data | Where | Evidence | Leaves the system? | Retention |
|---|---|---|---|---|
| Name, email, hashed password, external ID, claims sync time | `users` | `database/migrations/0001_01_01_000000_create_users_table.php`, `app/Models/User.php` | No | Until deleted. User deletion through the API is a stub (`UserController::destroy`) |
| IdP identity: provider, subject, email at link, last login | `user_identities` | `app/Services/Sso/SsoUserResolver.php` | Comes from the IdP | Deleted with the user |
| Roles, workgroups and custodian membership, synced from IdP or token claims (workgroups, roles, custodians, an NHS SDE approval flag) | `user_has_roles`, `user_has_workgroups`, `custodian_has_users` | `app/Services/Sso/ClaimMapper.php`, `app/Services/TokenSync/`, `config/claimsaccesscontrol.php` | Comes from the IdP | Overwritten on each sync |
| Every request: user ID, method, URI, status, IP, user agent, body (minus password and token) | `request_audits` | ✔ `app/Http/Middleware/AuditRequests.php` | No | Never deleted |
| Every request: method, URI, IP, full body | API log (stderr) | ✔ `app/Http/Middleware/LogHttpRequests.php` | To wherever container logs go | Set by the log platform |
| Free text sent to NLP, and the NLP response | API log; NLP log at INFO | `app/Traits/NLPConceptLookup.php`; NLP `app.py` | To wherever container logs go | Set by the log platform |
| Activity trail: the user, the event, and properties including parser free text, search filters, membership changes, SSO events and downloads | `activity_log` | `app/Services/Activity/ActivityLogger.php`, `QueryParserController.php`, `UserController.php`, `SsoController.php` | No | ✔ 365 days configured, never enforced |
| NLP query log: free text and what was extracted | `nlp_query_logs` | `app/Services/NLP/NLPConceptExtractor.php` (user ID hard-coded to 0, marked TODO) | No | Never deleted |
| Saved queries: user, name, definition | `queries` and related task and result tables | `app/Models/Query.php` | Definitions, without user details, go to collection hosts as tasks | Soft delete only |
| Concept sets and regression tests: user, name, description | `concept_sets`, `regression_tests` | migrations | No | Soft delete; removed with the user |
| Access tokens: user, scopes, expiry | `oauth_access_tokens` | `app/Services/Authentication/LocalPersonalAccessTokenService.php` | No | Expire after `STANDALONE_JWT_TTL_MINUTES` (stack: 120); never purged |
| Session token holding the user's ID, name, email, roles, workgroups and custodians | Browser cookie (`cds_stack_token` in the stack), httpOnly | web `src/lib/authCookie.ts` | Browser only | Token lifetime |
| IdP ID token, SSO hand-off codes and state | Redis cache | `app/Services/Sso/LogoutTicketStore.php`, `OneTimeCodeStore.php` | No | Token lifetime + 5 min; 60 s; 600 s |
| Sessions: user, IP, user agent | Redis (stack) | `config/session.php` | No | 120 minutes |
| Queued and failed jobs, which may hold serialised models | Redis / Horizon | `config/horizon.php` | No | 60 minutes; failed jobs 7 days |
| Requester email in the collection activation alert | Slack | ✔ `app/Services/Notifications/SlackNotifier.php` | **Yes, to Slack** | Set by Slack |
| User ID and query builder preferences | Browser local storage | web `src/store/queryBuilderStore.ts` | No | Never cleared |
| Map tiles and help videos | OpenStreetMap; YouTube embeds | web `src/config/map.ts`, `src/utils/youtube.ts` | **Yes**: IP and user agent to OpenStreetMap; IP and possibly cookies to YouTube | Set by the third party |
| User list with identities, searchable by name and email | `GET /api/v1/users`, gated by policy | `app/Http/Controllers/Api/V1/UserController.php` | To authorised callers | n/a |
| Generated passwords printed by the user import commands | Operator's terminal | `app/Console/Commands/ImportUsersFromCsv.php`, `ImportAdminUsers.php` | Terminal and shell history | n/a |
| Keycloak users (once S2 lands): fictional test users with verified email, groups and roles | Keycloak | `docs/tickets/S2-stack-keycloak.md` | No | Throwaway |

## Not found

No analytics or error-tracking service (Sentry, Google Analytics, Hotjar and similar), no email sending (the mailer logs only), no user details sent to collection hosts or the NLP service, and no log redaction. `collection_activity_logs` holds no personal data.

## Questions for the data protection owner

- What is the lawful basis for each purpose: sign-in and IdP sync, request auditing, the activity trail, query history, NLP logs and Slack alerts?
- What retention periods should apply to `request_audits`, `activity_log`, `nlp_query_logs`, saved queries, tokens and container logs?
- Is logging request bodies acceptable at all? Who receives container logs in each deployment, and is that a processor or a transfer?
- Free text a researcher types could contain special-category or patient data. Does the DPIA cover it?
- Is sending requesters' emails to Slack covered by a processor agreement?
- How are erasure and access requests handled? User deletion is a stub, `request_audits` keeps IP and payload after deletion, and users can't export their own data.
- Which IdP claims are needed? Is the NHS SDE approval flag a sensitive attribute?
- Do the YouTube and OpenStreetMap embeds need a cookie or consent notice?
