variable "image_repository" {
  description = "Docker image repository"
  type        = string
  default     = "ghcr.io/vladimir-kostic-devops/demo-web-app"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "main"
}

variable "container_name" {
  description = "Name of the Docker container"
  type        = string
  default     = "demo-web-app"
}

variable "host_port" {
  description = "Host port to expose the container on"
  type        = number
  default     = 8080
}
