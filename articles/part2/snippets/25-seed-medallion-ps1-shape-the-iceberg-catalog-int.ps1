# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contributors. Licensed under the Apache License, Version 2.0.
<#
.SYNOPSIS
  Shapes the Iceberg REST catalog into a medallion lakehouse for the streaming tutorial.
.DESCRIPTION
  Start-All.ps1 brings up a real Iceberg REST catalog on :18181 seeded with two demo namespaces
  (sales, finance). This script replaces that with a four-layer medallion lake that matches the
  Kafka -> Flink -> Iceberg -> Spark pipeline the tutorial tells:

    bronze     raw landing schema for the Kafka orders stream (demo job writes no rows)
    silver     cleaned, conformed, deduplicated          (Spark builds these)
    gold       curated business marts, analyst-facing    (Spark builds these)
    restricted sensitive marts: finance P&L, customer PII (drop-protected, analyst-blind)

  It talks straight to the Iceberg REST catalog (not through Aegis), the way a platform team would
  provision a lake out of band. The point of the tutorial is governing agent ACCESS to this lake,
  not the provisioning itself.
.NOTES
  Idempotent: safe to re-run. Called automatically at the end of Start-All.ps1.
#>
param([int]$CatalogPort = 18181)
$ErrorActionPreference = 'Stop'

# One HttpClient that never uses a system proxy (every call is loopback).
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.UseProxy = $false
$http = New-Object System.Net.Http.HttpClient($handler)
$http.Timeout = [TimeSpan]::FromSeconds(30)
$base = "http://127.0.0.1:$CatalogPort"

function Catalog([string]$Method, [string]$Path, [string]$Body) {
    $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), "$base$Path")
    if (-not [string]::IsNullOrEmpty($Body)) {
        $req.Content = New-Object System.Net.Http.StringContent($Body, [System.Text.Encoding]::UTF8, 'application/json')
    }
    $rsp = $http.SendAsync($req).GetAwaiter().GetResult()
    return [pscustomobject]@{ Status = [int]$rsp.StatusCode; Body = $rsp.Content.ReadAsStringAsync().GetAwaiter().GetResult() }
}

# Wait for the catalog to answer (Start-All already waits, but keep this runnable on its own).
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
    try { if ((Catalog 'GET' '/v1/config' $null).Status -eq 200) { break } } catch { }
    Start-Sleep -Milliseconds 500
}

# An Iceberg schema is a struct of typed fields. Field ids must be unique and stable.
function New-Schema([object[]]$Fields) {
    $fs = @()
    $i = 1
    foreach ($f in $Fields) {
        $fs += @{ id = $i; name = $f[0]; required = [bool]$f[1]; type = $f[2] }
        $i++
    }
    return (@{ type = 'struct'; 'schema-id' = 0; fields = $fs } | ConvertTo-Json -Depth 6 -Compress)
}

function New-Namespace([string]$Ns, [hashtable]$Props) {
    $body = @{ namespace = @($Ns); properties = $Props } | ConvertTo-Json -Depth 6 -Compress
    $r = Catalog 'POST' '/v1/namespaces' $body
    if ($r.Status -notin 200, 409) { throw "create namespace $Ns failed: HTTP $($r.Status) $($r.Body)" }
}

function New-Table([string]$Ns, [string]$Name, [string]$SchemaJson, [string]$Layer, [string]$Grain) {
    # Already there? leave it (idempotent).
    $exists = Catalog 'GET' "/v1/namespaces/$Ns/tables/$Name" $null
    if ($exists.Status -eq 200) { Write-Host ("  = {0,-28} (exists)" -f "$Ns.$Name"); return }
    $body = "{""name"":""$Name"",""schema"":$SchemaJson,""properties"":{""medallion.layer"":""$Layer"",""grain"":""$Grain""}}"
    $r = Catalog 'POST' "/v1/namespaces/$Ns/tables" $body
    if ($r.Status -ne 200) { throw "create table $Ns.$Name failed: HTTP $($r.Status) $($r.Body)" }
    Write-Host ("  + {0,-28} {1}" -f "$Ns.$Name", $Layer)
}

function Remove-NamespaceDeep([string]$Ns) {
    $list = Catalog 'GET' "/v1/namespaces/$Ns/tables" $null
    if ($list.Status -eq 404) { return }
    if ($list.Status -eq 200) {
        $ids = @(($list.Body | ConvertFrom-Json).identifiers)
        foreach ($id in $ids) {
            Catalog 'DELETE' "/v1/namespaces/$Ns/tables/$($id.name)?purgeRequested=true" $null | Out-Null
        }
    }
    Catalog 'DELETE' "/v1/namespaces/$Ns" $null | Out-Null
    Write-Host "  - removed default namespace $Ns"
}

Write-Host ""
Write-Host "=== shaping the Iceberg medallion lakehouse on $base ==="

# 1. Drop the two default demo namespaces so the lake is purely medallion.
foreach ($ns in 'sales', 'finance') { Remove-NamespaceDeep $ns }

# 2. Create the four layers.
foreach ($ns in 'bronze', 'silver', 'gold', 'restricted') {
    New-Namespace $ns @{ owner = 'platform-engineering'; 'medallion.layer' = $ns }
}

# 3. Bronze: raw landing schema. The demo Flink job does not write these tables.
New-Table 'bronze' 'orders_raw' (New-Schema @(
        @('kafka_offset', $true, 'long'), @('kafka_partition', $true, 'int'),
        @('ingest_ts', $true, 'timestamptz'), @('raw_payload', $true, 'string'))) 'bronze' 'event'
New-Table 'bronze' 'clickstream_raw' (New-Schema @(
        @('kafka_offset', $true, 'long'), @('ingest_ts', $true, 'timestamptz'),
        @('session_id', $false, 'string'), @('raw_payload', $true, 'string'))) 'bronze' 'event'
New-Table 'bronze' 'payments_raw' (New-Schema @(
        @('kafka_offset', $true, 'long'), @('ingest_ts', $true, 'timestamptz'),
        @('raw_payload', $true, 'string'))) 'bronze' 'event'

# 4. Silver: cleaned, conformed, deduplicated (Spark builds these from bronze).
New-Table 'silver' 'orders' (New-Schema @(
        @('order_id', $true, 'long'), @('customer_id', $true, 'long'),
        @('order_ts', $true, 'timestamptz'), @('amount', $true, 'decimal(12,2)'),
        @('currency', $true, 'string'), @('status', $true, 'string'))) 'silver' 'order'
New-Table 'silver' 'customers' (New-Schema @(
        @('customer_id', $true, 'long'), @('country', $true, 'string'),
        @('signup_ts', $true, 'timestamptz'), @('segment', $false, 'string'))) 'silver' 'customer'
New-Table 'silver' 'payments' (New-Schema @(
        @('payment_id', $true, 'long'), @('order_id', $true, 'long'),
        @('paid_ts', $true, 'timestamptz'), @('amount', $true, 'decimal(12,2)'),
        @('method', $true, 'string'))) 'silver' 'payment'

# 5. Gold: curated business marts, safe for analysts to read (Spark builds these from silver).
New-Table 'gold' 'daily_revenue' (New-Schema @(
        @('day', $true, 'date'), @('country', $true, 'string'),
        @('orders', $true, 'long'), @('revenue', $true, 'decimal(16,2)'))) 'gold' 'day-country'
New-Table 'gold' 'customer_ltv' (New-Schema @(
        @('customer_id', $true, 'long'), @('lifetime_orders', $true, 'long'),
        @('lifetime_value', $true, 'decimal(16,2)'), @('last_order_day', $false, 'date'))) 'gold' 'customer'
New-Table 'gold' 'product_performance' (New-Schema @(
        @('product_id', $true, 'long'), @('day', $true, 'date'),
        @('units', $true, 'long'), @('revenue', $true, 'decimal(16,2)'))) 'gold' 'product-day'

# 6. Restricted: sensitive marts. Analyst-blind (out of their scope) and drop-protected (DENY rule).
New-Table 'restricted' 'finance_pnl' (New-Schema @(
        @('period', $true, 'string'), @('gross_margin', $true, 'decimal(18,2)'),
        @('net_income', $true, 'decimal(18,2)'), @('forecast', $false, 'decimal(18,2)'))) 'restricted' 'period'
New-Table 'restricted' 'pii_customer' (New-Schema @(
        @('customer_id', $true, 'long'), @('full_name', $true, 'string'),
        @('email', $true, 'string'), @('national_id', $true, 'string'))) 'restricted' 'customer'

# Summary from the catalog itself.
$ns = @((Catalog 'GET' '/v1/namespaces' $null).Body | ConvertFrom-Json).namespaces
Write-Host ""
Write-Host "Medallion lake ready. Namespaces now in the catalog:"
foreach ($n in $ns) {
    $name = $n -join '.'
    $tbls = @((Catalog 'GET' "/v1/namespaces/$name/tables" $null).Body | ConvertFrom-Json).identifiers
    Write-Host ("  {0,-12} {1} tables: {2}" -f $name, $tbls.Count, (($tbls | ForEach-Object { $_.name }) -join ', '))
}
Write-Host ""
