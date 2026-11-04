output "ecr_repository_urls" {
  description = "Push targets for the pipelines"
  value       = { for k, r in aws_ecr_repository.svc : k => r.repository_url }
}

output "sns_topic_arn" {
  description = "Put this in the Jenkinsfile SNS_TOPIC_ARN"
  value       = aws_sns_topic.ci.arn
}

output "jenkins_role_arn" {
  description = "Used in Phase 4 to give Jenkins access to the EKS cluster"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  value = try(aws_eip.jenkins[0].public_ip, aws_instance.jenkins.public_ip)
}

output "ssm_shell_command" {
  description = "Open a shell on the Jenkins server (needs the Session Manager plugin)"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --region ${var.aws_region}"
}

output "ssm_port_forward_command" {
  description = "Then browse to http://localhost:8080"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --region ${var.aws_region} --document-name AWS-StartPortForwardingSession --parameters \"portNumber=8080,localPortNumber=8080\""
}

output "jenkins_initial_password_hint" {
  value = "In the SSM shell run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
