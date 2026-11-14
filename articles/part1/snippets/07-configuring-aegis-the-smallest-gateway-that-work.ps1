if (-not $env:AEGIS_HOME) { throw 'Set AEGIS_HOME to your aegis-mcp-gateway checkout. A new PowerShell window does not keep it.' }
if (-not (Test-Path .\hello.yaml)) { throw 'Save hello.yaml in this folder first, then cd here. A new window does not keep the directory.' }
$env:DEMO_TOKEN = 'a-demo-token-value'
java -jar "$env:AEGIS_HOME\aegis-gateway\target\aegis-gateway-2.0.0-SNAPSHOT-all.jar" --config hello.yaml
