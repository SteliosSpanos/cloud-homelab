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
