<?php

use App\Models\Custodian;
use App\Models\CustodianNetwork;
use App\Models\CustodianNetworkHasCustodian;
use App\Models\User;
use App\Models\Workgroup;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role;

ini_set('display_errors', 'stderr');

require '/var/www/vendor/autoload.php';

$app = require '/var/www/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$adminEmail = getenv('BOOTSTRAP_ADMIN_EMAIL');
$adminPassword = getenv('BOOTSTRAP_ADMIN_PASSWORD');
$custodianName = getenv('BOOTSTRAP_CUSTODIAN_NAME');
$networkName = 'Demo Network';
$adminName = 'Demo Admin';
$adminRoleName = 'admin';
$adminWorkgroupName = 'ADMIN';

if (! $adminEmail || ! $adminPassword || ! $custodianName) {
    fwrite(STDERR, "api-init: BOOTSTRAP_ADMIN_EMAIL, BOOTSTRAP_ADMIN_PASSWORD and BOOTSTRAP_CUSTODIAN_NAME must be set.\n");
    exit(1);
}

$adminRole = Role::where('name', $adminRoleName)->first();
$adminWorkgroup = Workgroup::where('name', $adminWorkgroupName)->first();

if (! $adminRole) {
    fwrite(STDERR, "api-init: role [{$adminRoleName}] must exist before the admin is created.\n");
    exit(1);
}

DB::transaction(function () use ($adminEmail, $adminPassword, $custodianName, $networkName, $adminName, $adminRole, $adminWorkgroup, $adminWorkgroupName) {
    $custodian = Custodian::firstOrCreate(['name' => $custodianName]);
    if ($custodian->external_custodian_id === null) {
        $custodian->update([
            'external_custodian_id' => $custodian->id,
            'external_custodian_name' => $custodian->name,
        ]);
    }
    echo "api-init: custodian [{$custodian->name}] is present.\n";

    $network = CustodianNetwork::firstOrCreate(['name' => $networkName], ['pid' => (string) Str::uuid()]);
    CustodianNetworkHasCustodian::firstOrCreate([
        'network_id' => $network->id,
        'custodian_id' => $custodian->id,
    ]);
    echo "api-init: custodian [{$custodian->name}] is in network [{$network->name}].\n";

    $admin = User::where('email', $adminEmail)->first();
    if (! $admin) {
        $admin = User::create([
            'name' => $adminName,
            'email' => $adminEmail,
            'password' => Hash::make($adminPassword),
        ]);
        echo "api-init: created the admin with the password from the stack's Secret.\n";
    } else {
        echo "api-init: the admin already exists; its password is left unchanged.\n";
    }

    $admin->roles()->syncWithoutDetaching([$adminRole->id]);
    $admin->custodians()->syncWithoutDetaching([$custodian->id]);
    echo "api-init: the admin has role [{$adminRole->name}] and custodian [{$custodian->name}].\n";

    if ($adminWorkgroup) {
        $admin->workgroups()->syncWithoutDetaching([$adminWorkgroup->id]);
        echo "api-init: the admin is in workgroup [{$adminWorkgroup->name}].\n";
    } else {
        echo "api-init: there is no [{$adminWorkgroupName}] workgroup, so the admin is in none; its role already gives it every collection.\n";
    }
});
