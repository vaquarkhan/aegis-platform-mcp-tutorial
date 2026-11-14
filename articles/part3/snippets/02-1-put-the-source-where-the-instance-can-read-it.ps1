cd articles\part3\code\terraform
Copy-Item .\passwords.auto.tfvars.example .\passwords.auto.tfvars
# Replace the four example passwords before continuing.
terraform init
terraform apply -var="bucket_name=YOUR-BUCKET"
terraform output aegis_identity_block
# When finished with the Terraform path:
terraform destroy -var="bucket_name=YOUR-BUCKET"
