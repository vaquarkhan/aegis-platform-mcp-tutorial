# Launch exactly one SSM-managed Windows instance for the run recorded by step 1.
param([string]$RuntimeDirectory = (Join-Path $env:LOCALAPPDATA 'AegisPart3'))
. (Join-Path $PSScriptRoot 'common.ps1')
$RuntimeDirectory = Initialize-Part3Runtime $RuntimeDirectory
$state = Read-Part3State $RuntimeDirectory
$P = @('--profile',$state.profile,'--region',$state.region)

$vpc = (Invoke-Aws (@('ec2','describe-vpcs','--filters','Name=isDefault,Values=true','--query','Vpcs[0].VpcId','--output','text') + $P)).Trim()
Assert-Value 'default VPC' $vpc '^vpc-[0-9a-f]+$'
$subnet = (Invoke-Aws (@('ec2','describe-subnets','--filters',"Name=vpc-id,Values=$vpc",'Name=default-for-az,Values=true','--query','Subnets[0].SubnetId','--output','text') + $P)).Trim()
Assert-Value 'default subnet' $subnet '^subnet-[0-9a-f]+$'

$sgName = "aegis-part3-$($state.runId)-no-inbound"
$sg = (Invoke-Aws (@('ec2','create-security-group','--group-name',$sgName,'--description','Aegis Part 3: SSM only, no inbound','--vpc-id',$vpc,'--tag-specifications',"ResourceType=security-group,Tags=[{Key=project,Value=aegis-part3},{Key=run-id,Value=$($state.runId)}]",'--query','GroupId','--output','text') + $P)).Trim()
Assert-Value 'security group' $sg '^sg-[0-9a-f]+$'
$ingress = (Invoke-Aws (@('ec2','describe-security-groups','--group-ids',$sg,'--query','length(SecurityGroups[0].IpPermissions)','--output','text') + $P)).Trim()
if ($ingress -ne '0') { throw "security group $sg has $ingress inbound rules" }

$ami = (Invoke-Aws (@('ssm','get-parameter','--name','/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base','--query','Parameter.Value','--output','text') + $P)).Trim()
Assert-Value 'AMI' $ami '^ami-[0-9a-f]+$'
$runArgs = @('ec2','run-instances','--image-id',$ami,'--instance-type','t3.xlarge','--subnet-id',$subnet,'--security-group-ids',$sg,
    '--iam-instance-profile',"Name=$($state.instanceProfileName)",'--associate-public-ip-address',
    '--block-device-mappings','DeviceName=/dev/sda1,Ebs={VolumeSize=80,VolumeType=gp3,DeleteOnTermination=true}',
    '--metadata-options','HttpTokens=required,HttpEndpoint=enabled',
    '--tag-specifications',"ResourceType=instance,Tags=[{Key=Name,Value=aegis-part3},{Key=project,Value=aegis-part3},{Key=run-id,Value=$($state.runId)}]", "ResourceType=volume,Tags=[{Key=project,Value=aegis-part3},{Key=run-id,Value=$($state.runId)}]",
    '--query','Instances[0].InstanceId','--output','text') + $P
$id = (Invoke-Aws $runArgs).Trim()
Assert-Value 'instance id' $id '^i-[0-9a-f]+$'
Invoke-Aws (@('ec2','wait','instance-running','--instance-ids',$id) + $P) | Out-Null
Invoke-Aws (@('ec2','wait','instance-status-ok','--instance-ids',$id) + $P) | Out-Null

$deadline = (Get-Date).AddMinutes(10)
do {
    Start-Sleep -Seconds 15
    $ping = (Invoke-Aws (@('ssm','describe-instance-information','--filters',"Key=InstanceIds,Values=$id",'--query','InstanceInformationList[0].PingStatus','--output','text') + $P)).Trim()
} while ($ping -ne 'Online' -and (Get-Date) -lt $deadline)
if ($ping -ne 'Online') { throw "instance $id did not become SSM Online" }

$state | Add-Member NoteProperty vpcId $vpc -Force
$state | Add-Member NoteProperty subnetId $subnet -Force
$state | Add-Member NoteProperty securityGroupId $sg -Force
$state | Add-Member NoteProperty amiId $ami -Force
$state | Add-Member NoteProperty instanceId $id -Force
Write-Part3State $RuntimeDirectory $state
Write-Output "STEP2_OK instance=$id ssm=$ping securityGroup=$sg inbound=0"
