<?php

/*
 * Authentication settings for the Cohort Discovery Service stack.
 *
 * This file is mounted over the API's own config/auth.php, so it replaces
 * the whole file: keep the guards, providers and password settings below
 * as they are unless the API's own copy changes. Every value is set here
 * rather than read from env (AUTH_GUARD, AUTH_MODEL, AUTH_PASSWORD_*), so
 * those env variables have no effect while this file is mounted.
 *
 * The setting a deployer is expected to change is 'password_login'.
 */

return [
    'defaults' => [
        'guard' => 'web',
        'passwords' => 'users',
    ],

    'guards' => [
        'web' => [
            'driver' => 'session',
            'provider' => 'users',
        ],
        'api' => [
            'driver' => 'passport',
            'provider' => 'users',
        ],
    ],

    'providers' => [
        'users' => [
            'driver' => 'eloquent',
            'model' => App\Models\User::class,
        ],
    ],

    'passwords' => [
        'users' => [
            'provider' => 'users',
            'table' => 'password_reset_tokens',
            'expire' => 60,
            'throttle' => 60,
        ],
    ],

    'password_timeout' => 10800,

    /*
     * Email and password sign-in on the app's own login form.
     *
     * false - only single sign-on through Keycloak is offered, and the API
     *         refuses password sign-in with 403. Every user, the admin
     *         included, must be a Keycloak user (keycloak.users in the chart
     *         values). If SSO isn't available, for example with Keycloak
     *         turned off, the API offers password sign-in anyway, so nobody
     *         is locked out.
     * true  - the login form offers email and password next to single
     *         sign-on. The API's own default.
     *
     * The scheduler isn't affected: it uses a client ID and secret.
     */
    'password_login' => [
        'enabled' => false,
    ],
];
