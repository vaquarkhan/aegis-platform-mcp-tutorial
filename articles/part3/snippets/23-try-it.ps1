python .\cli\bundle.py --gateway-root C:\path\to\aegis-mcp-gateway --tutorial-root C:\path\to\aegis-platform-mcp-tutorial
.\cli\01-upload-and-iam.ps1 -Bucket YOUR-BUCKET -Profile YOUR_PROFILE
.\cli\02-launch.ps1
.\cli\ssm.ps1 -ScriptPath .\remote\install.ps1 -Label install -TimeoutSeconds 5400
.\cli\ssm.ps1 -ScriptPath .\remote\run-tutorial.ps1 -Label tutorial -TimeoutSeconds 2400
.\cli\03-cognito.ps1
.\cli\ssm.ps1 -ScriptPath .\remote\jwt-gateway.ps1 -Label jwt -TimeoutSeconds 1800
.\cli\ssm.ps1 -ScriptPath .\remote\upload-evidence.ps1 -Label evidence -TimeoutSeconds 600
.\cli\04-verify-evidence.ps1 -GatewayJar C:\path\to\aegis-gateway-kafka-2.0.0-SNAPSHOT-all.jar
.\cli\99-teardown.ps1              # prints the exact deletion plan and stops
.\cli\99-teardown.ps1 -Force       # deletes only this run; keeps evidence
