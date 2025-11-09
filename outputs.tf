output "ssh_key_path" {
  value = local_file.pem.filename
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_public_dns" {
  value = aws_instance.jenkins.public_dns
}

output "ecr_repo_url" {
  value = aws_ecr_repository.demo.repository_url
}

output "eks_update_kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "jenkins_initial_password_hint" {
  value = "ssh -i jenkins-key.pem ec2-user@${aws_instance.jenkins.public_dns} && docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
}
