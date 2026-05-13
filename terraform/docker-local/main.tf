terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Pull the image from GHCR
resource "docker_image" "demo_web_app" {
  name         = "${var.image_repository}:${var.image_tag}"
  keep_locally = true
}

# Run the container
resource "docker_container" "demo_web_app" {
  name  = var.container_name
  image = docker_image.demo_web_app.image_id

  ports {
    internal = 80
    external = var.host_port
  }

  env = [
    "ASPNETCORE_URLS=http://+:80"
  ]

  restart = "unless-stopped"
}
