variable "key_name" {
  description = "The name of the AWS Key Pair to use for SSH"
  type        = string
}

variable "private_key_path" {
  description = "The local path to your .pem file for Ansible authentication"
  type        = string
  default     = "./labsuser.pem"
}
