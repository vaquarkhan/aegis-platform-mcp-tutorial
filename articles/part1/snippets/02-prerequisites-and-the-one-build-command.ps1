git clone -b aegis-mcp-gateway-2.0-review-ready https://github.com/vaquarkhan/aegis-mcp-gateway.git
cd aegis-mcp-gateway
if (-not (Test-Path .\examples\break-glass-mcp-servers\lib\BreakGlassMcp.psm1)) { throw 'Wrong branch. This tutorial needs aegis-mcp-gateway-2.0-review-ready.' }
mvn -B -Preal-engines -DskipTests install
$env:AEGIS_HOME = (Get-Location).Path
