terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.00"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {}
}

# Authenticate to EKS directly via AWS APIs (no kubeconfig file required).
data "aws_eks_cluster" "cluster_name" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = data.aws_eks_cluster.cluster_name.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster_name.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_name.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster_name.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster_name.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}
