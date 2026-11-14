# Runs ON the EC2 instance via SSM. Installs JDK 17, Maven 3.9, Git, pulls the bundle, builds Aegis.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
foreach ($name in 'AEGIS_PART3_BUCKET','AEGIS_PART3_REGION','AEGIS_PART3_BASE_KEY','AEGIS_PART3_BUNDLE_SHA256') {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "missing environment variable $name (send this script through cli/ssm.ps1)" }
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Root = 'C:\aegis'
New-Item -ItemType Directory -Force -Path $Root, "$Root\tools", "$Root\dl" | Out-Null
$Log = "$Root\install.log"
function Log($m) { $line = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content $Log $line; Write-Output $line }
Log 'install start'

function Fetch($url, $dest) {
    if (Test-Path $dest) { Log "have $dest"; return }
    $ok = $false
    foreach ($try in 1..3) {
        try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing; $ok = $true; break } catch { Log "download retry $try $url : $($_.Exception.Message)"; Start-Sleep 5 }
    }
    if (-not $ok) { throw "download failed $url" }
    Log "downloaded $dest $((Get-Item $dest).Length) bytes"
}

# JDK 17 (Amazon Corretto, zip, no installer)
$jdkZip = "$Root\dl\corretto17.zip"
Fetch 'https://corretto.aws/downloads/latest/amazon-corretto-17-x64-windows-jdk.zip' $jdkZip
if (-not (Get-ChildItem "$Root\tools" -Directory -Filter 'jdk17*' -ErrorAction SilentlyContinue)) {
    Expand-Archive $jdkZip -DestinationPath "$Root\tools\jdk17-x" -Force
    $inner = Get-ChildItem "$Root\tools\jdk17-x" -Directory | Select-Object -First 1
    Move-Item $inner.FullName "$Root\tools\jdk17"
    Remove-Item "$Root\tools\jdk17-x" -Recurse -Force
}
$env:JAVA_HOME = "$Root\tools\jdk17"

# Maven 3.9 (archive.apache.org serves all 3.9.x)
$mvnZip = "$Root\dl\maven.zip"
Fetch 'https://archive.apache.org/dist/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.zip' $mvnZip
if (-not (Test-Path "$Root\tools\apache-maven-3.9.11")) { Expand-Archive $mvnZip -DestinationPath "$Root\tools" -Force }

# Git (MinGit, portable)
$gitZip = "$Root\dl\mingit.zip"
Fetch 'https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/MinGit-2.47.1-64-bit.zip' $gitZip
if (-not (Test-Path "$Root\tools\mingit")) { Expand-Archive $gitZip -DestinationPath "$Root\tools\mingit" -Force }

$env:Path = "$env:JAVA_HOME\bin;$Root\tools\apache-maven-3.9.11\bin;$Root\tools\mingit\cmd;$env:Path"
[Environment]::SetEnvironmentVariable('JAVA_HOME', $env:JAVA_HOME, 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$env:JAVA_HOME\bin;$Root\tools\apache-maven-3.9.11\bin;$Root\tools\mingit\cmd;" + [Environment]::GetEnvironmentVariable('Path', 'Machine'), 'Machine')
Log ("java: " + ((& java -version 2>&1) -join ' | '))
Log ("mvn: " + ((& mvn -v 2>&1 | Select-Object -First 1) -join ' '))
Log ("git: " + ((& git --version 2>&1) -join ' '))

# Source bundle from the exact per-run S3 key (instance role).
$Bucket = $env:AEGIS_PART3_BUCKET
$zip = "$Root\dl\aegis-part3-src.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Read-S3Object -BucketName $Bucket -Key "$env:AEGIS_PART3_BASE_KEY/aegis-part3-src.zip" -File $zip -Region $env:AEGIS_PART3_REGION | Out-Null
$sha = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
Log "bundle sha256=$sha"
if ($sha -ne $env:AEGIS_PART3_BUNDLE_SHA256) { throw "bundle hash mismatch: got $sha" }
if (Test-Path "$Root\src") { Remove-Item "$Root\src" -Recurse -Force }
Expand-Archive $zip -DestinationPath "$Root\src" -Force
Log ("src: " + ((Get-ChildItem "$Root\src" -Directory | Select-Object -ExpandProperty Name) -join ', '))

# Build the gateway with the real-engine profile. Same command as Part 1.
Set-Location "$Root\src\aegis-mcp-gateway"
if (-not (Test-Path .\examples\break-glass-mcp-servers\lib\BreakGlassMcp.psm1)) { throw 'wrong branch: no BreakGlassMcp.psm1' }
$buildLog = "$Root\build.log"
Log 'mvn -B -Preal-engines -DskipTests install  (this is the slow step)'
$sw = [Diagnostics.Stopwatch]::StartNew()
& cmd /c "mvn -B -q -Preal-engines -DskipTests install > `"$buildLog`" 2>&1"
$code = $LASTEXITCODE
$sw.Stop()
Log "mvn exit=$code elapsed=$([int]$sw.Elapsed.TotalSeconds)s"
Get-Content $buildLog -Tail 15 | ForEach-Object { Log "  $_" }
foreach ($f in @('aegis-gateway\target\aegis-gateway-2.0.0-SNAPSHOT-all.jar',
                 'examples\aegis-gateway-kafka\target\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar',
                 'examples\aegis-validation-kafka-server\target\server.classpath',
                 'examples\aegis-validation-iceberg-server\target\server.classpath')) {
    Log ("artifact {0} exists={1}" -f $f, (Test-Path $f))
}
if ($code -ne 0) { throw "maven failed $code" }
Log 'INSTALL_OK'
