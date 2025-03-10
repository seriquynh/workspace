#!/usr/bin/env pwsh

$baseDir = $PWD

$tty = '-it'

$dockerCompose = "docker compose -f '$baseDir\docker\docker-compose.yml'"

if (Test-Path "$baseDir\docker\docker-compose.local.yml") {
    $dockerCompose = "$dockerCompose -f '$baseDir\docker\docker-compose.local.yml'"
}

$command = ''
$extraArgs = ''

Foreach ($arg in $args) {
    if ($arg -eq $args[0]) {
        $command = $arg
        continue
    }

    $extraArgs = $extraArgs + ' ' + $arg
}

if ($command -eq '') {
    $command = 'ps'
}

if ($command -eq "artisan") {
    $commandLine = "$dockerCompose exec $TTY -e DB_HOST=mysql -e DB_PORT=3306 app php artisan $extraArgs"
} elseif ($command -eq "composer") {
    $commandLine = "$dockerCompose exec $TTY -e DB_HOST=mysql -e DB_PORT=3306 app composer $extraArgs"
} elseif ($command -eq "mysql") {
    $commandLine = "$dockerCompose exec $TTY mysql mysql $extraArgs"
} elseif ($command -eq "pest") {
    $commandLine = "$dockerCompose exec $TTY -e APP_ENV=testing app ./vendor/bin/pest $extraArgs"
} elseif ($command -eq "phpstan") {
    $commandLine = "docker run -it --rm -v .:/opt seriquynh/laravel-test-runner:latest phpstan $extraArgs"
} elseif ($command -eq "pint") {
    $commandLine = "docker run -it --rm -v .:/opt seriquynh/laravel-test-runner:latest pint $extraArgs"
} else {
    $commandLine = "$dockerCompose $command $extraArgs"
}

Invoke-Expression $commandLine
