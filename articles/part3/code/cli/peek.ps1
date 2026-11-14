# Show status and the tail of a running SSM command's stdout.
param([string]$Label = 'install', [int]$Tail = 25)
$aws = 'aws'
$Here = $PSScriptRoot
$Id = (Get-Content (Join-Path $Here 'instance-id.txt') -Raw).Trim()
$first = Get-Content (Join-Path $Here "ssm-$Label.log") -First 1
$cmd = ($first -replace '^command=([0-9a-f-]+).*', '$1')
$json = & $aws ssm get-command-invocation --command-id $cmd --instance-id $Id --output json --profile YOUR_PROFILE --region us-east-1 2>&1 | Out-String
try { $o = $json | ConvertFrom-Json } catch { Write-Output $json; exit }
Write-Output "status=$($o.Status)"
$lines = @($o.StandardOutputContent -split "`r?`n") | Where-Object { $_ }
$lines | Select-Object -Last $Tail
if ($o.StandardErrorContent) { Write-Output '--- stderr tail'; @($o.StandardErrorContent -split "`r?`n") | Select-Object -Last 8 }
