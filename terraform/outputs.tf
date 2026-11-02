output "public_ec2_public_ip" {
  description = "Public IP of the Public Application Server (Scenario 1)"
  value       = aws_instance.public_ec2.public_ip
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion Jump Host (Scenario 2 - Option 1)"
  value       = aws_instance.bastion.public_ip
}

output "private_ec2_private_ip" {
  description = "Private IP of the Private Application Server (Scenario 2 - Option 1 & 2)"
  value       = aws_instance.private_ec2.private_ip
}

output "private_ec2_instance_id" {
  description = "Instance ID of the Private Server for AWS Systems Manager (Scenario 2 - Option 2)"
  value       = aws_instance.private_ec2.id
}

output "github_deployer_access_key_id" {
  description = "Access Key ID for the GitHub Actions IAM user"
  value       = var.create_iam_user ? aws_iam_access_key.github_deployer_key[0].id : null
}

output "github_deployer_secret_access_key" {
  description = "Secret Access Key for the GitHub Actions IAM user"
  value       = var.create_iam_user ? aws_iam_access_key.github_deployer_key[0].secret : null
  sensitive   = true
}

output "ssh_key_name" {
  description = "The EC2 Key Pair name associated with all instances"
  value       = local.selected_key_name
}

output "private_key_pem_file" {
  description = "Path to the generated private key file on your computer"
  value       = var.auto_generate_key_pair ? local_file.private_key_pem[0].filename : "Using existing key: ${var.key_name}"
}

output "github_secrets_summary" {
  description = "Summary of GitHub Actions Secrets values to configure"
  value = {
    EC2_PUBLIC_IP        = aws_instance.public_ec2.public_ip
    BASTION_HOST         = aws_instance.bastion.public_ip
    PRIVATE_EC2_IP       = aws_instance.private_ec2.private_ip
    EC2_INSTANCE_ID      = aws_instance.private_ec2.id
    AWS_REGION           = var.aws_region
    AWS_ACCESS_KEY_ID    = var.create_iam_user ? aws_iam_access_key.github_deployer_key[0].id : "<CONFIGURE_MANUALLY>"
    BASTION_SSH_KEY_FILE = var.auto_generate_key_pair ? "Open ${local_file.private_key_pem[0].filename} and copy contents" : "Use your existing ${var.key_name}.pem"
  }
}


