# Optional. Skip while Start-All is running: it already owns 14040, 16066, and 17077.
$sparkArgs = (Get-ChildItem .\run\engine-spark\engine-*\spark.args | Select-Object -Last 1).FullName
java "@$sparkArgs" SparkServices 14040 16066 17077
# in a second shell, once READY has printed (Spark takes longer than Flink, allow up to a minute):
curl.exe http://127.0.0.1:14040/api/v1/applications
