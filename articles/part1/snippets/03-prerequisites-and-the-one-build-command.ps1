git clone https://github.com/vaquarkhan/aegis-platform-mcp-tutorial.git
cd aegis-platform-mcp-tutorial
if (-not (Test-Path .\Approve-Cancel.ps1) -or -not (Test-Path .\Seed-Medallion.ps1)) { throw 'This checkout is older than the article. Pull again, or check the repo for the Part 2 scripts.' }
.\Start-All.ps1
