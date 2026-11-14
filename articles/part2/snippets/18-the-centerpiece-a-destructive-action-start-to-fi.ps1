# The schema requires exactly 32 characters. Pasting the angle-bracket note fails before Flink is called.
$state = Get-Content -Raw .\run\state.json | ConvertFrom-Json
$jobId = [string]$state.facts.'flink.jobId'
.\mcp.ps1 -Persona operator -Tool flink_cancel_job -Arguments @{ jobId = $jobId }
