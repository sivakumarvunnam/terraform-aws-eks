## kubernetes externaldns

locals {
  #namespace                     = lookup(var.externaldns_helm, "namespace", "kube-system")
  #serviceaccount                = lookup(var.externaldns_helm, "serviceaccount", "external-dns")
  #oidc_fully_qualified_subjects = format("system:serviceaccount:%s:%s", lookup(var.externaldns_helm, "namespace", "kube-system"), lookup(var.externaldns_helm, "serviceaccount", "external-dns"))
}

# security/policy
resource "aws_iam_role" "externaldns" {
  count = var.irsa_externaldns_enabled ? 1 : 0
  name  = join("-", ["irsa", local.clustername, "external-dns"])
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
          format("%s:sub", local.oidc["url"]) = format("system:serviceaccount:%s:%s", lookup(var.externaldns_helm, "namespace", "kube-system"), lookup(var.externaldns_helm, "serviceaccount", "external-dns"))
        }
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "externaldns" {
  count       = var.irsa_externaldns_enabled ? 1 : 0
  name        = join("-", ["irsa", local.clustername, "external-dns"])
  description = format("Allow externaldns to manage AWS Route53 records")
  path        = "/"
  policy      = file("${path.module}/templates/externaldns_policy.json")
}

resource "aws_iam_role_policy_attachment" "externaldns" {
  count      = var.irsa_externaldns_enabled ? 1 : 0
  policy_arn = aws_iam_policy.externaldns.0.arn
  role       = aws_iam_role.externaldns[0].name
  depends_on = [aws_iam_role.externaldns, aws_iam_policy.externaldns]
}

resource "helm_release" "externaldns" {
  count           = var.irsa_externaldns_enabled ? 1 : 0
  name            = lookup(var.externaldns_helm, "name", "external-dns")
  chart           = lookup(var.externaldns_helm, "chart", "external-dns")
  version         = lookup(var.externaldns_helm, "version", null)
  repository      = lookup(var.externaldns_helm, "repository", "https://charts.bitnami.com/bitnami")
  namespace       = local.namespace
  cleanup_on_fail = lookup(var.externaldns_helm, "cleanup_on_fail", true)

  dynamic "set" {
    for_each = {
      "aws.region"                                                = var.aws_region
      "rbac.create"                                               = true
      "serviceAccount.name"                                       = lookup(var.externaldns_helm, "serviceaccount", "external-dns")
      "serviceAccount.create"                                     = true
      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.externaldns[0].arn
      "aws.zoneType"                                              = lookup(var.externaldns_helm, "zoneType", "public")
      "domainFilters"                                             = "{avettatech.com}"
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
