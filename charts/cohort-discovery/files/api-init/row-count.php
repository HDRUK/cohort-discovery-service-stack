<?php

ini_set('display_errors', 'stderr');

require '/var/www/vendor/autoload.php';

$app = require '/var/www/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

[, $connection, $table] = $argv;

echo Illuminate\Support\Facades\DB::connection($connection)->table($table)->count();
