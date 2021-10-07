aws_region = "us-west-2"
azs        = ["us-west-2a", "us-west-2b", "us-west-2c"]
name       = "dev-ws-safety-eks"
tags = {
  env         = "ws"
  project     = "ws-safety"
  ssm_managed = "enabled"
}
kubernetes_version = "1.19"
enable_ssm         = true
node_groups = [
  {
    name          = "mixed-ws-safety"
    min_size      = 1
    max_size      = 3
    desired_size  = 2
    instance_type = "t3.medium"
    instances_distribution = {
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "capacity-optimized"
    }
    instances_override = [
      {
        instance_type     = "t3.small"
        weighted_capacity = 2
      },
      {
        instance_type     = "t3.large"
        weighted_capacity = 1
      }
    ]
  },
  {
    name          = "default-ws-safety-ng"
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    instance_type = "t3.large"
  }
]
managed_node_groups = [
  {
    name          = "default-ws-safety-wng"
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    instance_type = "t3.large"
  }
]
