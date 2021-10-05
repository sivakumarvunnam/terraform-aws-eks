# Autoscaling example

terraform {
  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

# eks
module "eks" {
  source              = "git::https://github.com/sivakumarvunnam/terraform-aws-eks.git?ref=main"
  name                = var.name
  tags                = var.tags
  kubernetes_version  = var.kubernetes_version
  managed_node_groups = var.managed_node_groups
  node_groups         = var.node_groups
  fargate_profiles    = var.fargate_profiles
  enable_ssm          = var.enable_ssm
}

provider "helm" {
  kubernetes {
    host                   = module.eks.helmconfig.host
    token                  = module.eks.helmconfig.token
    cluster_ca_certificate = base64decode(module.eks.helmconfig.ca)
  }
}

## kubernetes node termination handler
module "helm-release" {
  source = "git::https://github.com/sivakumarvunnam/terraform-helm-release.git?ref=main"
  release = {
    ### aws-node-termination-handler
    aws-node-termination-handler = {
      repository_name     = "eks-charts"
      chart               = "aws-node-termination-handler"
      repository          = "https://aws.github.io/eks-charts"
      repository_username = null
      repository_password = null
      version             = null
      verify              = false
      reuse_values        = false
      reset_values        = false
      force_update        = false
      timeout             = 3600
      recreate_pods       = false
      max_history         = 200
      wait                = false
      values              = null
      set                 = null
      namespace           = "kube-system"
      create_namespace    = true
    }
    ### metrics-server
    metrics-server = {
      repository_name     = "stable"
      chart               = "metrics-server"
      repository          = "https://charts.helm.sh/stable"
      repository_username = null
      repository_password = null
      version             = null
      verify              = false
      reuse_values        = false
      reset_values        = false
      force_update        = false
      timeout             = 3600
      recreate_pods       = false
      max_history         = 200
      wait                = false
      values              = null
      set                 = null
      namespace           = "kube-system"
      create_namespace    = true
      set = [
        {
          name  = "args[0]"
          value = "--kubelet-preferred-address-types=InternalIP"
        }
      ]
    }
  }
}

### configure kubectl provider
provider "kubectl" {
  host                   = module.eks.helmconfig.host
  token                  = module.eks.helmconfig.token
  cluster_ca_certificate = base64decode(module.eks.helmconfig.ca)
  load_config_file       = false
}
###
data "kubectl_filename_list" "kubenetesdashboard_manifests" {
  pattern = "./templates/recommended.yaml"
}
### resource to deploy kubenetesdashboard
resource "kubectl_manifest" "kubenetesdashboard" {
  count     = length(data.kubectl_filename_list.kubenetesdashboard_manifests.matches)
  yaml_body = file(element(data.kubectl_filename_list.kubenetesdashboard_manifests.matches, count.index))
}
data "kubectl_filename_list" "efk_manifests" {
  pattern = "./fluentd/*.yaml"
}
### resource to deploy efk
resource "kubectl_manifest" "efk" {
  count     = length(data.kubectl_filename_list.efk_manifests.matches)
  yaml_body = file(element(data.kubectl_filename_list.efk_manifests.matches, count.index))
}
