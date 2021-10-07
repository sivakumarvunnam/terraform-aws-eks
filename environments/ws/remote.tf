terraform {
  backend "remote" {
    organization = "sg-tech"

    workspaces {
      name = "terraform-eks-dev"
    }
  }
}
