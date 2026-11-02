# ------------------------------------------------------------------------------
# Automated SSH Key Pair Generation & Local PEM File Export
# ------------------------------------------------------------------------------

resource "tls_private_key" "ec2_key" {
  count     = var.auto_generate_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  count      = var.auto_generate_key_pair ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ec2_key[0].public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "local_file" "private_key_pem" {
  count           = var.auto_generate_key_pair ? 1 : 0
  content         = tls_private_key.ec2_key[0].private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0600"
}

locals {
  selected_key_name = var.auto_generate_key_pair ? aws_key_pair.generated_key[0].key_name : var.key_name
}
