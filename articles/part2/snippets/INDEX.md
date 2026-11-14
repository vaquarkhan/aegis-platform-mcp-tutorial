# Part 2 code blocks, in article order

Every fenced block in `DZONE-ARTICLE-PART2.md`, one file each, numbered as it appears. Files ending in `.txt` are captured output, not commands to run.

| File | Section | Language | First line |
| --- | --- | --- | --- |
| `01-flink-a-real-minicluster-with-one-endless-stream.java` | Flink: a real MiniCluster with one endless streaming job | `java` | `import org.apache.flink.api.common.JobID;` |
| `02-flink-a-real-minicluster-with-one-endless-stream.ps1` | Flink: a real MiniCluster with one endless streaming job | `powershell` | `# Optional. Skip while Start-All is running: it already owns` |
| `03-spark-a-standalone-master-plus-a-running-applica.java` | Spark: a standalone Master plus a running application | `java` | `import java.util.List;` |
| `04-spark-a-standalone-master-plus-a-running-applica.ps1` | Spark: a standalone Master plus a running application | `powershell` | `# Optional. Skip while Start-All is running: it already owns` |
| `05-spark-a-standalone-master-plus-a-running-applica.ps1` | Spark: a standalone Master plus a running application | `powershell` | `$body = @{ action = 'CreateSubmissionRequest'; clientSparkVe` |
| `06-kafka-a-real-kraft-broker-connect-and-the-orders.java` | Kafka: a real KRaft broker, Connect, and the orders topic | `java` | `import java.util.List;` |
| `07-kafka-a-real-kraft-broker-connect-and-the-orders.ps1` | Kafka: a real KRaft broker, Connect, and the orders topic | `powershell` | `# Leave Start-All running. This does not bind a port; it tal` |
| `08-kafka-a-real-kraft-broker-connect-and-the-orders.ps1` | Kafka: a real KRaft broker, Connect, and the orders topic | `powershell` | `# Leave Start-All running so Connect is listening on 18083. ` |
| `09-iceberg-the-real-rest-catalog-shaped-into-the-me.ps1` | Iceberg: the real REST catalog, shaped into the medallion lake | `powershell` | `# Optional. Skip while Start-All is running: it already owns` |
| `10-iceberg-the-real-rest-catalog-shaped-into-the-me.ps1` | Iceberg: the real REST catalog, shaped into the medallion lake | `powershell` | `$schema = @{ type='struct'; 'schema-id'=0; fields=@(` |
| `11-the-governance-file-one-yaml-that-is-the-whole-g.yaml` | The governance file: one YAML that is the whole gateway | `yaml` | `gateway:` |
| `12-the-governance-file-one-yaml-that-is-the-whole-g.txt` | The governance file: one YAML that is the whole gateway | `text` | `java -jar "$env:AEGIS_HOME\examples\aegis-gateway-kafka\targ` |
| `13-the-governance-file-one-yaml-that-is-the-whole-g.txt` | The governance file: one YAML that is the whole gateway | `text` | `java -jar "$env:AEGIS_HOME\examples\aegis-gateway-kafka\targ` |
| `14-the-operator-reads-the-whole-pipeline.ps1` | The operator reads the whole pipeline | `powershell` | `.\mcp.ps1 -Persona operator -Tool kafka_list_topics` |
| `15-the-operator-reads-the-whole-pipeline.json` | The operator reads the whole pipeline | `json` | `// operator -> flink_get_cluster_info` |
| `16-the-operator-reads-the-whole-pipeline.ps1` | The operator reads the whole pipeline | `powershell` | `.\mcp.ps1 -Persona operator -Tool iceberg_drop_table -Argume` |
| `17-the-operator-reads-the-whole-pipeline.json` | The operator reads the whole pipeline | `json` | `{"result":{"content":[{"text":` |
| `18-the-centerpiece-a-destructive-action-start-to-fi.ps1` | The centerpiece: a destructive action, start to finish | `powershell` | `# The schema requires exactly 32 characters. Pasting the ang` |
| `19-the-centerpiece-a-destructive-action-start-to-fi.json` | The centerpiece: a destructive action, start to finish | `json` | `"Aegis denied this call: APPROVAL_REQUIRED (step 4). this DE` |
| `20-the-centerpiece-a-destructive-action-start-to-fi.txt` | The centerpiece: a destructive action, start to finish | `text` | `operator (eve) POST /aegis/v1/approvals/{id}/approve   ->   ` |
| `21-the-centerpiece-a-destructive-action-start-to-fi.txt` | The centerpiece: a destructive action, start to finish | `text` | `approver (bob)  POST /aegis/v1/approvals/{id}/approve  ->  H` |
| `22-the-centerpiece-a-destructive-action-start-to-fi.txt` | The centerpiece: a destructive action, start to finish | `text` | `outcome: ALLOWED` |
| `23-the-centerpiece-a-destructive-action-start-to-fi.txt` | The centerpiece: a destructive action, start to finish | `text` | `outcome: DENIED:APPROVAL_REQUIRED:step4` |
| `24-start-all-ps1-start-the-four-engines-the-gateway.ps1` | `Start-All.ps1`: start the four engines, the gateway, and seed the lake | `powershell` | `# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contr` |
| `25-seed-medallion-ps1-shape-the-iceberg-catalog-int.ps1` | `Seed-Medallion.ps1`: shape the Iceberg catalog into bronze, silver, gold, restricted | `powershell` | `# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contr` |
| `26-run-walkthrough-ps1-drive-the-whole-read-and-den.ps1` | `Run-Walkthrough.ps1`: drive the whole read and deny scenario and save a transcript | `powershell` | `# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contr` |
| `27-approve-cancel-ps1-the-governed-destructive-acti.ps1` | `Approve-Cancel.ps1`: the governed destructive action, end to end | `powershell` | `# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contr` |
| `28-stop-all-ps1-stop-the-gateway-and-the-four-engin.ps1` | `Stop-All.ps1`: stop the gateway and the four engines | `powershell` | `# Copyright 2026 Viquar Khan and the Aegis MCP Gateway contr` |
