<?php

ini_set('display_errors', 'stderr');

require '/var/www/vendor/autoload.php';

$app = require '/var/www/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$omop = Illuminate\Support\Facades\DB::connection('omop');

if (! $omop->getSchemaBuilder()->hasTable('vocabulary')) {
    exit(0);
}

echo $omop->table('vocabulary')->where('vocabulary_id', 'None')->value('vocabulary_version') ?? '';
