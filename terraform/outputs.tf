output "ssh_commands" {
  description = "SSH connection commands (use the config file)"
  value = {
    jump_box     = "ssh -F .ssh/config jump-box"
    nat_instance = "ssh -F .ssh/config nat-instance"
    main_vm      = "ssh -F .ssh/config main-vm"
  }
}

output "jump_box_public_ip" {
  description = "Jump box public IP (Elastic IP)"
  value       = aws_eip.jump_box.public_ip
}

output "nat_instance_private_ip" {
  description = "NAT instance private IP"
  value       = aws_instance.nat_instance.private_ip
}

output "main_vm_private_ip" {
  description = "Main VM private IP"
  value       = aws_instance.main_vm.private_ip
}

output "web_app_public_ip" {
  description = "Web App public IP"
  value       = aws_instance.web_app.public_ip
}

output "web_app_private_ip" {
  description = "Web App private IP"
  value       = aws_istance.web_app.private_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.homelab.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.homelab.arn
}

output "db_endpoint" {
  description = "RDS PostgresSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}
