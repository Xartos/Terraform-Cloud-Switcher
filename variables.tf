# route53
variable "hosted_zone" {
  description = "Hosted zone used by Route53 (e.g. example.com)"
}

variable "aws_capacity" {
  description = "Number of VMs in the aws cloudpool"
}

variable "azure_capacity" {
  description = "Number of VMs in the azure cloudpool"
}

variable "server_port" {
  description = "Server HTTP request port"
  default     = 80
}

variable "application_port" {
  description = "The port that you want to expose to the external load balancer"
  default     = 80
}

variable "admin_user" {
  description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
  default     = "myadmin"
}

variable "admin_password" {
  description = "Default password for admin account"
}

# variable "aws_address" {
#   description = "Address to the AWS loadbalancer"
# }

