aws iam create-role --role-name aegis-part3-ec2 --assume-role-policy-document file://trust.json --tags Key=project,Value=aegis-part3
aws iam attach-role-policy --role-name aegis-part3-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam put-role-policy --role-name aegis-part3-ec2 --policy-name aegis-part3-s3 --policy-document file://inline.json
aws iam create-instance-profile --instance-profile-name aegis-part3-ec2
aws iam add-role-to-instance-profile --instance-profile-name aegis-part3-ec2 --role-name aegis-part3-ec2
