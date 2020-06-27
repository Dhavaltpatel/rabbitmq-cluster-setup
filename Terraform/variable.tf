### variable.tf
variable "aws_region" {
  description = "AWS region on which we will setup the rabbitmq cluster"
  default = "us-east-2"
}
variable "access_key" {
  default = ""
  description = "the user aws access key"
}
variable "secret_key" {
  default = ""
  description = "the user aws secret key"
}

variable "keypair_name" {
  default = ""
}

variable "aws_ami" {
  default = ""
  description = "Mention the ubuntu ami id here."
}

variable "vpc_id"{
  description = "add the vpc id in which infrastructure is to be created"
  default = ""
}

variable "subnet_id" {
  description = "External subnets of the VPC"
  type        = list(string)
  default     = ["", "", ""]
}

variable "network_address_space" {
  default = "10.1.0.0/16"
}

variable "subnet_count" {
  default = 3
}

variable "instance_count" {
  default = 3
}

variable "controller_count" {
  default = 3
}

variable "name" {
  default = "rabbit"
}

variable "instance_type" {
  description = "Instance type"
  default = "t2.medium"
}

variable "min_size" {
  description = "Minimum number of RabbitMQ nodes"
  default     = 3
}

variable "desired_size" {
  description = "Desired number of RabbitMQ nodes"
  default     = 3
}

variable "max_size" {
  description = "Maximum number of RabbitMQ nodes"
  default     = 5
}

variable "nodes_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "elb_additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "environment_tag" {
  default = "production"
}

/*variable "key_path" {
  description = "SSH Public Key path"
  default = ""
}
variable "key_name" {
  description = "Desired name of Keypair..."
  default = ""
}*/


variable "ingress_public_cidr_blocks" {
  default = ["0.0.0.0/0"]
}

variable "internet_public_cidr_blocks" {
  default = ["0.0.0.0/0"]
}

variable "ingress_private_cidr_blocks" {
  default = ["10.1.0.0/16"]
}
