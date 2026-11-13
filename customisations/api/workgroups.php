<?php

/*
 * The workgroups the API creates for the Cohort Discovery Service stack.
 *
 * This file is mounted over the API's own config/workgroups.php. The init
 * Job runs WorkgroupSeeder on every start: it creates each name below that
 * doesn't exist yet (stored in upper case, matched ignoring case) and never
 * deletes or renames one.
 *
 * Every workgroup named in claimsaccesscontrol.php's workgroup_mappings
 * must be listed here, or signing in can't give it to anyone.
 *
 * The API's own list also seeds these, which this stack leaves out:
 *   'admin'     - the admin role already sees every collection.
 *   'custodian' - custodians see their collections through their custodian.
 *   'default'   - added to every user when 'ensure_default' is on in
 *                 claimsaccesscontrol.php (it's off in this stack).
 *   'other'     - a catch-all workgroup.
 */

return [
    'seed' => [
        'uk-research',
        'uk-industry',
        'non-uk-research',
        'non-uk-industry',
        // NHS-SDE also turns off the web's access banner for its members.
        'nhs-sde',
    ],
];
