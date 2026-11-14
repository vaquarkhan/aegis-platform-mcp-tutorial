$body = @{ action = 'CreateSubmissionRequest'; clientSparkVersion = '4.0.1'
    appResource = 'file:/opt/jobs/aegis-example-job.jar'; mainClass = 'org.example.NightlyAggregation'
    appArgs = @(); environmentVariables = @{}
    sparkProperties = @{ 'spark.app.name' = 'nightly-aggregation'; 'spark.master' = 'spark://127.0.0.1:17077'
        'spark.submit.deployMode' = 'cluster'; 'spark.driver.supervise' = 'false' } } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:16066/v1/submissions/create' -ContentType 'application/json' -Body $body
