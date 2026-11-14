# Leave Start-All running. This does not bind a port; it talks to the broker on 19092.
$seedArgs = (Get-ChildItem .\run\engine-kafka\engine-*\seed.args | Select-Object -Last 1).FullName
java "@$seedArgs" KafkaSeed 127.0.0.1:19092
