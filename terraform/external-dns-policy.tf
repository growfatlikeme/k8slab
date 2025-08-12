resource "aws_iam_policy" "external_dns" {
  name_prefix = "${local.name_prefix}-external-dns-"
  description = "External DNS policy for Route53 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = data.aws_route53_zone.hosteddns.arn
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}