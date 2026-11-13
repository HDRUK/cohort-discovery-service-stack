<?php

/*
 * Claims mapping and sync policy for the Cohort Discovery Service stack.
 *
 * This file is mounted over the API's own config/claimsaccesscontrol.php.
 * Every value is set here rather than read from env, so this file is the
 * one place to see how sign-in claims become workgroups, roles and
 * custodians. The API's own copy reads the same settings from env
 * (JWT_*_SECONDS, CLAIM_SYNC_*, CLAIM_PROVISION_*); those env variables
 * have no effect while this file is mounted.
 */

return [
    /*
     * Integrated mode only (Gateway JWTs, not Keycloak sign-in): how long a
     * per-token sync lock is held, and how long a second request waits for
     * it, in seconds. Unused in standalone mode. API defaults: 10 and 2.
     */
    'sync_lock_seconds' => 10,
    'sync_lock_wait_seconds' => 2,
    /**
     * Workgroup mappings allow us to override the known workgroups within
     * Hdruk's ClaimsBasedAccessControl package. This basically allows
     * you to provide local workgroups, that map 1:1 to that of the
     * package.
     *
     * The order is as follows:
     * 'internal-workgroups' => 'external-workgroups'
     *
     * There is currently no scope to provide workgroups that are
     * unknown to ClaimsBasedAccessControl package.
     *
     * The default workgroup mappings are for HDRUK gateway
     */
    /*
     * In this stack: 'CDS workgroup' => 'Keycloak group', or a list of
     * Keycloak groups (keycloak.groups in the chart values). A user in any
     * of the listed groups gets the workgroup. Matching ignores case.
     *
     * Every workgroup here must be in workgroups.php, which the init Job
     * seeds; signing in never creates a workgroup.
     *
     * One Keycloak group can also feed several workgroups: give it in each
     * (gsk below, a multinational counted as both UK and non-UK industry).
     * Keycloak groups that aren't listed, such as 'default', give no
     * workgroup.
     */
    'workgroup_mappings' => [
        'uk-research' => ['ukri', 'ncs', 'breathe'],
        'uk-industry' => ['astrazeneca', 'gsk'],
        'non-uk-industry' => 'gsk',
        'non-uk-research' => 'bbmri',
        'nhs-sde' => 'nhs-wales',
    ],

    /*
     * 'CDS role' => 'Keycloak realm role' (keycloak.roles in the chart values).
     * The CDS roles are user, admin and custodian.
     */
    'role_mappings' => [
        'user' => 'researcher',
        'admin' => 'platform-admin',
        'custodian' => 'data-custodian',
    ],

    /*
     * When and how each kind of membership is taken from the IdP's claims.
     *
     * trust:
     *   'always'      - sync on every sign-in (this stack: Keycloak is the
     *                   source of truth, D4).
     *   'first_login' - sync once, on the user's first sign-in; after that
     *                   the app manages it. The API's default for workgroups.
     *   'never'       - ignore the claim; the app manages it. Any value other
     *                   than these three is treated as 'never'.
     *
     * authoritative:
     *   true  - replace the user's memberships with exactly what the claim
     *           says, so removing a group in Keycloak removes it here.
     *   false - only add what the claim says; nothing is ever removed.
     *           The API's default for workgroups.
     *
     * A claim missing from the token is read as "no information" and changes
     * nothing, even when authoritative (see A7).
     */
    'sync' => [
        'workgroups' => [
            'trust' => 'always',
            'authoritative' => true,
            // true: every user always keeps the DEFAULT workgroup, whatever the claim says.
            // false: DEFAULT is only kept if the claim maps to it.
            // Off here, because this stack doesn't seed a DEFAULT workgroup (workgroups.php).
            'ensure_default' => false,
            // Integrated mode only: add the NHS SDE workgroups when the Gateway token
            // marks the user as SDE-approved. Unused in standalone mode.
            'sde_from_claim' => true,
        ],

        'roles' => [
            'trust' => 'always',
            'authoritative' => true,
            // true: every user always keeps the 'user' role, whatever the claim says.
            'ensure_default' => true,
        ],

        'custodians' => [
            'trust' => 'always',
            'authoritative' => true,
        ],

        'provision' => [
            // true: a user created by SSO sign-in starts with the DEFAULT workgroup
            // (if it exists; it doesn't in this stack) and the 'user' role before
            // any claims are applied.
            // false: they start with nothing but what the claims give them.
            'defaults_on_create' => true,
        ],
    ],
];
