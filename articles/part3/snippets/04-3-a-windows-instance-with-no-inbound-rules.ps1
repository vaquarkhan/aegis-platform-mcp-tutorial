$sg  = aws ec2 create-security-group --group-name aegis-part3-no-inbound --description 'SSM only' --vpc-id $vpc --query GroupId --output text
$ami = aws ssm get-parameter --name /aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base --query Parameter.Value --output text
aws ec2 run-instances --image-id $ami --instance-type t3.xlarge --subnet-id $subnet --security-group-ids $sg `
  --iam-instance-profile Name=aegis-part3-ec2 `
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=80,VolumeType=gp3,DeleteOnTermination=true}' `
  --metadata-options HttpTokens=required,HttpEndpoint=enabled `
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=aegis-part3},{Key=project,Value=aegis-part3}]'
aws ec2 describe-security-groups --group-ids $sg --query 'length(SecurityGroups[0].IpPermissions)'
