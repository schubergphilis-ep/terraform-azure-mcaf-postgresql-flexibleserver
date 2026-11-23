output "password" {
  description = "The generated password. Null when the password is supplied through the ephemeral input."
  value       = var.generate_password ? random_password.this[0].result : null
  sensitive   = true
}
