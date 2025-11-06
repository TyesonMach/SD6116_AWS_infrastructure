output "ecr_urls" {
  description = "ECR repository URIs"
  value       = module.ecr.repository_urls
}

output "kubeconfig_cmd" {
  description = "Run this locally to configure kubectl for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}

output "jenkins_url" {
  value = module.jenkins_ec2.jenkins_url
}
