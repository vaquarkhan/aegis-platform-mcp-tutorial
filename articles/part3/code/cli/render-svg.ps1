param([string]$Svg = 'C:\path\to\aegis-platform-mcp-tutorial\aws-architecture.svg',
      [string]$Png = 'C:\path\to\aegis-platform-mcp-tutorial\aws-architecture.png')
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$uri = 'file:///' + ($Svg -replace '\\', '/')
$p = Start-Process -FilePath $edge -ArgumentList '--headless=new', '--disable-gpu', '--hide-scrollbars', "--user-data-dir=$env:TEMP\edge-svg-preview", '--window-size=1320,900', "--screenshot=$Png", $uri -PassThru -WindowStyle Hidden
$p.WaitForExit(30000) | Out-Null
if (Test-Path $Png) { "rendered $Png $((Get-Item $Png).Length) bytes" } else { 'RENDER_FAILED' }
