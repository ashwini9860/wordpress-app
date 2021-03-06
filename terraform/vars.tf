variable "project" {
  default = "clever"
}
variable "AWS_REGION_NAME" {
  default = "ap-south-1"
}


variable "VPC_CIDR_BLOCK" {
  default = "172.33.0.0/16"
}
variable "AVAILABILITY_ZONE" {
  type    = "list"
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1a"]
}


variable "task_role" {
  description = "Name of the IAM Role assumed by ECS Tasks"
  default     = "kubernetes"
}

variable "ingress_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [22, 80, 2049]
}
variable "ingress_protocol" {
  default = "tcp"
}

