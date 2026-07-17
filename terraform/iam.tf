data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "kops_master" {
  name               = "${local.name_prefix}-kops-master"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-kops-master"
  }
}

resource "aws_iam_instance_profile" "kops_master" {
  name = "${local.name_prefix}-kops-master"
  role = aws_iam_role.kops_master.name
}

resource "aws_iam_role_policy" "kops_master" {
  name = "${local.name_prefix}-kops-master-policy"
  role = aws_iam_role.kops_master.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "ec2:*",
          "elasticloadbalancing:*",
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:GetRole",
          "iam:ListInstanceProfilesForRole",
          "iam:PassRole",
          "iam:RemoveRoleFromInstanceProfile",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "s3:*",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "kops_node" {
  name               = "${local.name_prefix}-kops-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-kops-node"
  }
}

resource "aws_iam_instance_profile" "kops_node" {
  name = "${local.name_prefix}-kops-node"
  role = aws_iam_role.kops_node.name
}

resource "aws_iam_role_policy_attachment" "kops_node_ecr" {
  role       = aws_iam_role.kops_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "kops_node" {
  name = "${local.name_prefix}-kops-node-policy"
  role = aws_iam_role.kops_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "s3:GetBucketLocation",
          "s3:GetEncryptionConfiguration",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = "*"
      },
    ]
  })
}
