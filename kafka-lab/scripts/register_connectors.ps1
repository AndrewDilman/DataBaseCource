# Регистрация JDBC source/sink в Kafka Connect (после docker compose up)
$base = "http://localhost:8083/connectors"
$ErrorActionPreference = "Stop"

function Register-Connector($path) {
    $body = Get-Content $path -Raw -Encoding UTF8
    $name = (ConvertFrom-Json $body).name
    try {
        Invoke-RestMethod -Method Delete -Uri "$base/$name" -ErrorAction SilentlyContinue | Out-Null
    } catch { }
    Invoke-RestMethod -Method Post -Uri $base -ContentType "application/json" -Body $body
    Write-Host "Registered: $name"
}

$root = Split-Path -Parent $PSScriptRoot
Register-Connector "$root\connect\jdbc-source-outbox.json"
Register-Connector "$root\connect\jdbc-sink-aggregates.json"
