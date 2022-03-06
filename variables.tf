variable "name" {
  type        = string
  default     = "lucid-project"
  description = "Root name for resources in this project"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  type        = string
  description = "VPC cidr block"
}

variable "aws_region" {
  type = string
  default = "us-east-1" 
}

variable "ec2_amis" {
  description = "ami to support t2-nano instance"
  type        = "map"

  default = {
    "us-east-1" = "ami-04169656fea786776"
    }
}


variable "availability_zones" {
  type = list
  default = ["us-east-1a", "us-east-1b"]
}


variable "instance_type" {
  default = "t2.nano"
}


variable "public_subnets_cidr" {
  type = "list"
  default = ["10.0.0.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  type = "list"
  default = ["10.0.1.0/24", "10.0.3.0/24"]
}


# RDS - Postgres

variable "rds_identifier" {
  default = "db"
}

variable "rds_instance_type" {
  default = "db.t2.micro"
}

variable "rds_storage_size" {
  default = "5"
}

variable "rds_engine" {
  default = "postgres"
}

variable "rds_engine_version" {
  default = "9.5.2"
}

variable "rds_db_name" {
  default = "rds_db"
}

variable "rds_admin_user" {
  default = "dbadmin"
}

variable "rds_admin_password" {
  default = "super_secret_password"
}

variable "rds_publicly_accessible" {
  default = "false"


