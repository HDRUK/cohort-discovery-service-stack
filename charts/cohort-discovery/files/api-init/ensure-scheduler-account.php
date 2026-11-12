<?php

use App\Models\ServiceAccount;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\Hash;

ini_set('display_errors', 'stderr');

require '/var/www/vendor/autoload.php';

$app = require '/var/www/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$name = getenv('SCHEDULER_SERVICE_ACCOUNT_NAME');
$clientId = getenv('SCHEDULER_CLIENT_ID');
$clientSecret = getenv('SCHEDULER_CLIENT_SECRET');

if (! $name || ! $clientId || ! $clientSecret) {
    fwrite(STDERR, "api-init: SCHEDULER_SERVICE_ACCOUNT_NAME, SCHEDULER_CLIENT_ID and SCHEDULER_CLIENT_SECRET must be set.\n");
    exit(1);
}

$account = ServiceAccount::where('name', $name)->first();

if (! $account) {
    ServiceAccount::create([
        'name' => $name,
        'client_id' => $clientId,
        'client_secret' => $clientSecret,
    ]);
    echo "api-init: created service account [{$name}] from the stack's Secret.\n";
    exit(0);
}

if ($account->client_id === $clientId && Hash::check($clientSecret, $account->client_secret)) {
    echo "api-init: service account [{$name}] already matches the stack's Secret.\n";
    exit(0);
}

$account->update([
    'client_id' => $clientId,
    'client_secret' => $clientSecret,
]);
echo "api-init: service account [{$name}] differed from the stack's Secret and was updated to match it.\n";
