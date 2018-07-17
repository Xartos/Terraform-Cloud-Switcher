variable "hosted_zone" {
  description = "Hosted zone used by Route53 (e.g. example.com)"
}

variable "group_size" {
  description = "Number of VMs in the cloudpool"
  default     = 2
}

variable "server_port" {
  description = "Server HTTP request port"
  default     = 80
}
