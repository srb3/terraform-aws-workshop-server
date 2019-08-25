output "server_public_ip" {
  description = "A list of the public ip addresses of the created servers"
  value       = module.server.public_ip
}

output "server_private_ip" {
  description = "A list of the private ip addresses of the created servers"
  value       = module.server.private_ip
}

output "guacamole_user" {
  description = "The name of the user used for remote access"
  value = var.user_name
}

output "guacamole_pass" {
  description = "A generated password that could be used for setting the Guacamole ui login"
  value = random_string.guacamole_access_password.result
}

output "guacamole_connections" {
  description = "A list of client connection detials for consumption by the Guacamole module"
  value       = local.connections
}
