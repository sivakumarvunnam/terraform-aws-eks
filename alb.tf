## kubernetes aws-load-balancer-controller
locals {
  namespace                     = lookup(var.alb_helm, "namespace", "kube-system")
  serviceaccount                = lookup(var.alb_helm, "serviceaccount", "aws-load-balancer-controller")
  oidc_fully_qualified_subjects = format("system:serviceaccount:%s:%s", local.namespace, local.serviceaccount)
}

# security/policy
resource "aws_iam_role" "albc" {
  count = var.irsa_alb_enabled ? 1 : 0
  name  = join("-", ["irsa", local.clustername, "aws-load-balancer-controller"])
  path  = "/"
  tags  = merge(local.default-tags)
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = local.oidc["arn"]
      }
      Condition = {
        StringEquals = {
          format("%s:sub", local.oidc["url"]) = local.oidc_fully_qualified_subjects
        }
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "albc" {
  count       = var.irsa_alb_enabled ? 1 : 0
  name        = join("-", ["irsa", local.clustername, "aws-load-balancer-controller"])
  description = format("Allow aws-load-balancer-controller to manage AWS resources")
  path        = "/"
  policy      = file("${path.module}/templates/alb_policy.json")
}

resource "aws_iam_role_policy_attachment" "albc" {
  count      = var.irsa_alb_enabled ? 1 : 0
  policy_arn = aws_iam_policy.albc.0.arn
  role       = aws_iam_role.albc[0].name
  depends_on = [aws_iam_role.albc, aws_iam_policy.albc]
}

resource "helm_release" "albc" {
  count           = var.irsa_alb_enabled ? 1 : 0
  name            = lookup(var.alb_helm, "name", "aws-load-balancer-controller")
  chart           = lookup(var.alb_helm, "chart", "aws-load-balancer-controller")
  version         = lookup(var.alb_helm, "version", null)
  repository      = lookup(var.alb_helm, "repository", "https://aws.github.io/eks-charts")
  namespace       = local.namespace
  cleanup_on_fail = lookup(var.alb_helm, "cleanup_on_fail", true)

  dynamic "set" {
    for_each = {
      "clusterName"                                               = aws_eks_cluster.cp.name
      "serviceAccount.name"                                       = local.serviceaccount
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.albc[0].arn
    }
    content {
      name  = set.key
      value = set.value
    }
  }
  depends_on = [
    aws_eks_cluster.cp,
    aws_autoscaling_group.ng,
    kubernetes_config_map.aws-auth
  ]
}
