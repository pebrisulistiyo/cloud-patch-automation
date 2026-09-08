# Instance role: the SSM agent needs just this one managed policy, enough to
# report inventory, run patch documents, and open Session Manager channels.
resource "aws_iam_role" "ssm" {
  name = "patch-demo-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = aws_iam_role.ssm.name
  role = aws_iam_role.ssm.name
}
