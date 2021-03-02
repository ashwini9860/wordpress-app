variable "AWS_REGION_NAME" {
  default = "ap-south-1"
}

variable "environment" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "The environment variables to pass to the container. This is a list of maps. map_environment overrides environment"
  default = [
    {
      name  = "WORDPRESS_DB_PASSWORD"
      value = "wordpress"
    },
    {
      name  = "WORDPRESS_DB_USER"
      value = "wordpress"
    },
    {
      name  = "WORDPRESS_DB_NAME"
      value = "wordpress"
    },
    {
      name  = "WORDPRESS_DB_HOST"
      value = "db:3306"
    }

  ]

}
