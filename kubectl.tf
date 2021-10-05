locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cp.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cp.certificate_authority[0].data}
  name: ${aws_eks_cluster.cp.name}
contexts:
- context:
    cluster: ${aws_eks_cluster.cp.name}
    user: ${aws_eks_cluster.cp.name}
  name: ${aws_eks_cluster.cp.name}
current-context: ${aws_eks_cluster.cp.name}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.cp.name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.cp.name}"
KUBECONFIG

  eks_admin = <<EKSADMIN
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-admin
  namespace: kube-system

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: eks-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: eks-admin
  namespace: kube-system
EKSADMIN

}
### create a null_resource to create outout folder in the source code
resource "null_resource" "output" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/output/${var.name}"
  }
}
### create kubeconfig to connect to kube cluster to run the kubectl manifests
resource "local_file" "kubeconfig" {
  content  = local.kubeconfig
  filename = "${path.root}/output/${var.name}/kubeconfig-${var.name}"

  depends_on = [null_resource.output]
}
