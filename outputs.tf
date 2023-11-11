output "Ansible-Sandbox-PublicIP" {
  value       = aws_instance.example.public_ip
  description = "The public IP address of the Ansible server"
}
