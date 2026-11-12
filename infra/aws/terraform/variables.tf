variable "aws_region" {
  description = "AWS region where the lab is deployed."
  type        = string
  default     = "eu-north-1"
}

variable "vpc_name" {
  description = "Name tag for the lab VPC."
  type        = string
  default     = "aws-lab"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}


variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for the first private subnet."
  type        = string
  default     = "10.20.11.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for the second private subnet."
  type        = string
  default     = "10.20.12.0/24"
}

variable "availability_zone_a" {
  description = "Availability Zone for the public and first private subnet."
  type        = string
  default     = "eu-north-1a"
}

variable "availability_zone_b" {
  description = "Availability Zone for the second private subnet."
  type        = string
  default     = "eu-north-1b"
}

variable "public_route_cidr" {
  description = "Destination CIDR for the public default route."
  type        = string
  default     = "0.0.0.0/0"
}
