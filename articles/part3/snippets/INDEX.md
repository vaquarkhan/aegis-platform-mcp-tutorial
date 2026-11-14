# Part 3 code blocks, in article order

Every fenced block in `DZONE-ARTICLE-PART3.md`, one file each, numbered as it appears. Files ending in `.txt` are captured output, not commands to run.

| File | Section | Language | First line |
| --- | --- | --- | --- |
| `01-1-put-the-source-where-the-instance-can-read-it.ps1` | 1. Put the source where the instance can read it | `powershell` | `cd articles\part3\code` |
| `02-1-put-the-source-where-the-instance-can-read-it.ps1` | 1. Put the source where the instance can read it | `powershell` | `cd articles\part3\code\terraform` |
| `03-2-an-instance-role-with-the-least-it-needs.ps1` | 2. An instance role with the least it needs | `powershell` | `aws iam create-role --role-name aegis-part3-ec2 --assume-rol` |
| `04-3-a-windows-instance-with-no-inbound-rules.ps1` | 3. A Windows instance with no inbound rules | `powershell` | `$sg  = aws ec2 create-security-group --group-name aegis-part` |
| `05-3-a-windows-instance-with-no-inbound-rules.txt` | 3. A Windows instance with no inbound rules | `text` | `0` |
| `06-4-install-and-build-on-the-instance.txt` | 4. Install and build on the instance | `text` | `19:57:46 java: openjdk version "17.0.21" 2026-10-20 LTS  Cor` |
| `07-5-run-part-1-and-part-2-unchanged.txt` | 5. Run Part 1 and Part 2 unchanged | `text` | `=== starting real flink ===     flink ready: jobId=bfd7cf971` |
| `08-5-run-part-1-and-part-2-unchanged.txt` | 5. Run Part 1 and Part 2 unchanged | `text` | `P1 reader gold        ALLOWED  customer_ltv, daily_revenue, ` |
| `09-5-run-part-1-and-part-2-unchanged.txt` | 5. Run Part 1 and Part 2 unchanged | `text` | `2) a non-approver (operator eve) tries to approve: must be r` |
| `10-create-the-pool-from-the-cli.ps1` | Create the pool from the CLI | `powershell` | `$pool   = aws cognito-idp create-user-pool --pool-name aegis` |
| `11-create-the-pool-from-the-cli.ps1` | Create the pool from the CLI | `powershell` | `aws cognito-idp admin-initiate-auth --user-pool-id $pool --c` |
| `12-create-the-pool-from-the-cli.txt` | Create the pool from the CLI | `text` | `token ana: iss=https://cognito-idp.us-east-1.amazonaws.com/u` |
| `13-the-only-part-of-aegis-yaml-that-changes.yaml` | The only part of aegis.yaml that changes | `yaml` | `egress:` |
| `14-the-only-part-of-aegis-yaml-that-changes.txt` | The only part of aegis.yaml that changes | `text` | `healthz 18090: {"status":"ok"}` |
| `15-the-same-story-with-real-tokens.txt` | The same story with real tokens | `text` | `J1  random string as bearer           HTTP 401 {"error":"aut` |
| `16-the-same-story-with-real-tokens.txt` | The same story with real tokens | `text` | `J10 eve  dry-run                      ALLOWED  approvalReque` |
| `17-the-same-story-with-real-tokens.json` | The same story with real tokens | `json` | `{"id":"apr_62aba7c0d60143d46c678e8e3a32e862","status":"APPRO` |
| `18-the-same-story-with-real-tokens.txt` | The same story with real tokens | `text` | `J14 eve  GET /approvals/{id}          HTTP 200  token=aat1..` |
| `19-how-aegis-defended-the-destructive-action-on-aws.txt` | How Aegis defended the destructive action on AWS | `text` | `records=30` |
| `20-evidence-that-leaves-the-machine.txt` | Evidence that leaves the machine | `text` | `uploaded aegis-platform.jsonl      sha256=6386aedb... bytes=` |
| `21-evidence-that-leaves-the-machine.txt` | Evidence that leaves the machine | `text` | `aegis-platform-jwt.jsonl   sha256 local=68409a69d0d6 s3meta=` |
| `22-evidence-that-leaves-the-machine.txt` | Evidence that leaves the machine | `text` | `verify tampered (record 3 SCOPE_DENIED->ALLOWED): BROKEN rec` |
| `23-try-it.ps1` | Try it | `powershell` | `python .\cli\bundle.py --gateway-root C:\path\to\aegis-mcp-g` |
