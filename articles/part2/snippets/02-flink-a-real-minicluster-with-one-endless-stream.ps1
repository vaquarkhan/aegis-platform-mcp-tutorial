# Optional. Skip while Start-All is running: it already owns port 18081.
# Run .\Stop-All.ps1 first, then .\Start-All.ps1 again before the governed calls below.
$flinkArgs = (Get-ChildItem .\run\engine-flink\engine-*\flink.args | Select-Object -Last 1).FullName
java "@$flinkArgs" FlinkCluster 18081
# in a second shell, once READY has printed:
curl.exe http://127.0.0.1:18081/overview
curl.exe http://127.0.0.1:18081/jobs/overview
