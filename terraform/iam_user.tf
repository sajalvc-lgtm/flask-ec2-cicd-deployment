# ------------------------------------------------------------------------------
# IAM User and Access Keys for GitHub Actions SSM Deployment
# ------------------------------------------------------------------------------

resource "aws_iam_user" "github_deployer" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.project_name}-github-deployer"
  path  = "/system/"

  tags = {
    Description = "IAM User with programmatic access for GitHub Actions EC2 deployment"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "ssm_deploy_policy" {
  count       = var.create_iam_user ? 1 : 0
  name        = "${var.project_name}-ssm-deploy-policy"
  description = "Least privilege policy allowing GitHub Actions to trigger SSM Run Command on EC2"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMCommandExecution"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:document/AWS-RunShellScript",
          "arn:aws:ec2:${var.aws_region}:*:instance/*"
        ]
      },
      {
        Sid    = "SSMStatusAndDiagnostics"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "attach_ssm_policy" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.github_deployer[0].name
  policy_arn = aws_iam_policy.ssm_deploy_policy[0].arn
}

resource "aws_iam_access_key" "github_deployer_key" {
  count = var.create_iam_user ? 1 : 0
  user  = aws_iam_user.github_deployer[0].name
}
