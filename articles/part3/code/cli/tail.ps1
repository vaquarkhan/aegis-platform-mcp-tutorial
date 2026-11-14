# Tail remote log files on the instance with a short SSM command.
param([string[]]$Files = @('C:\aegis\install.log', 'C:\aegis\build.log'), [int]$Lines = 12)
$aws = 'aws'
$P = @('--profile', 'YOUR_PROFILE', '--region', 'us-east-1')
$Id = (Get-Content (Join-Path $PSScriptRoot 'instance-id.txt') -Raw).Trim()
$cmds = @()
foreach ($f in $Files) { $cmds += "Write-Output '== $f'"; $cmds += "Get-Content '$f' -Tail $Lines -ErrorAction SilentlyContinue" }
$paramsFile = Join-Path $PSScriptRoot 'tail.params.json'
[IO.File]::WriteAllText($paramsFile, (@{ commands = $cmds } | ConvertTo-Json -Compress))
$c = & $aws ssm send-command --instance-ids $Id --document-name AWS-RunPowerShellScript --parameters "file://$paramsFile" --query Command.CommandId --output text @P
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep 5
    $s = & $aws ssm get-command-invocation --command-id $c --instance-id $Id --query Status --output text @P 2>$null
    if ($s -notin @('Pending', 'InProgress', 'Delayed')) { break }
}
& $aws ssm get-command-invocation --command-id $c --instance-id $Id --query StandardOutputContent --output text @P
