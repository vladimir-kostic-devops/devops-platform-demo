output "container_id" {
  description = "ID of the running Docker container"
  value       = docker_container.demo_web_app.id
}

output "container_name" {
  description = "Name of the running Docker container"
  value       = docker_container.demo_web_app.name
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://localhost:${var.host_port}"
}
