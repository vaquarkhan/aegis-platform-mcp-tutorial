# Part 3 infrastructure as Terraform

Same resources the `cli/` scripts create, one module per concern.

```
terraform/
  main.tf, variables.tf, outputs.tf      root: provider and module composition
  modules/network/                       default VPC lookup, security group with 0 inbound rules
  modules/iam/                           instance role + profile: SSM core, S3 read of the bundle prefix, write of evidence/
  modules/compute/                       Windows Server 2022 t3.xlarge, IMDSv2 required, 80 GB gp3, no key pair
  modules/cognito/                       user pool, app client (no secret), groups platform-readers/-operators/-approvers, users ana/eve/bob/outsider
  passwords.auto.tfvars.example          copy to passwords.auto.tfvars and set your own
```

```powershell
terraform init
terraform validate
terraform apply -var="bucket_name=YOUR-BUCKET"           # passwords.auto.tfvars is picked up automatically
terraform output -raw instance_id > ..\cli\instance-id.txt
terraform output aegis_identity_block                    # paste under host: in aegis-aws.yaml
```

Then the same remote steps as the CLI path: `..\cli\ssm.ps1 -ScriptPath ..\remote\install.ps1 -Label install`, `run-tutorial.ps1`, `jwt-gateway.ps1`, `upload-evidence.ps1`. Finish with `terraform destroy`. The instance is the only thing that keeps charging.

Not created here: the S3 bucket (pass an existing one), and nothing on the instance (install.ps1 does that). The article was run with the CLI scripts; this Terraform passes `init`, `fmt -check`, and `validate` on Terraform 1.14 with AWS provider 5.x and describes the same design, but was not applied for the article.
