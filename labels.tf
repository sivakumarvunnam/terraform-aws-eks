resource "random_string" "uid" {
  length  = 5
  upper   = false
  lower   = true
  number  = false
  special = false
}

locals {
  service = "eks"
  uid     = join("-", [local.service, random_string.uid.result])
  name    = var.name == null || var.name == "" ? local.uid : var.name
  clustername = join("-", [var.name, random_string.uid.result])
  default-tags = merge(
    { "terraform.io" = "managed" },
    local.eks-owned-tag
  )
}

## kubernetes tags
locals {
  eks-shared-tag = {
    format("kubernetes.io/cluster/%s", local.clustername) = "shared"
  }
  eks-owned-tag = {
    format("kubernetes.io/cluster/%s", local.clustername) = "owned"
  }
  eks-elb-tag = {
    "kubernetes.io/role/elb" = "1"
  }
  eks-internal-elb-tag = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  eks-autoscaler-tag = {
    "k8s.io/cluster-autoscaler/enabled"                = "true"
    format("k8s.io/cluster-autoscaler/%s", local.clustername) = "owned"
  }
  eks-tag = merge(
    {
      "eks:cluster-name" = local.clustername
    },
    local.eks-owned-tag,
    local.eks-autoscaler-tag,
  )
}
