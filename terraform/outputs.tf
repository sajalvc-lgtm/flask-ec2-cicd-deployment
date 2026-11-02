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

output "github_secrets_summary" {
  description = "Summary of GitHub Actions Secrets values to configure"
  value = {
    EC2_PUBLIC_IP        = aws_instance.public_ec2.public_ip
    BASTION_HOST         = aws_instance.bastion.public_ip
    PRIVATE_EC2_IP       = aws_instance.private_ec2.private_ip
    EC2_INSTANCE_ID      = aws_instance.private_ec2.id
    AWS_REGION           = var.aws_region
  }
}
