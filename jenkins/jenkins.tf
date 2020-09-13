terraform {
  backend "s3" {
    bucket = "tf-state-cp20200912214428139300000001"
    key = "tfstate/jenkins"
    region = "us-west-2"
    dynamodb_table = "TfStateLocking"
  }
}

provider "aws" {
  region = "us-west-2"
}


data "aws_vpc" "default_vpc" {
  default = true
}

variable "home_ip" {
  type = string
  description = "Ip CIDR of home machine"
}

resource "aws_security_group" "jenkins_admin" {
  name        = "jenkins_admin"
  description = "Allow TLS inbound traffic"
  vpc_id      = data.aws_vpc.default_vpc.id

  ingress {
    description = "TLS from home"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  ingress {
    description = "Http from home"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  ingress {
    description = "SSH from home"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins_admin"
  }
}

data "aws_ami" "fcos_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["fedora-coreos-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["125523088429"] # Fedora CoreOS
}


variable "keypair_name" {
  type = string
  description = "Name of the keypair to use to launch instances with"
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_launch_template" "jenkins_launch_template" {
  name          = "jenkins"
  image_id      = data.aws_ami.fcos_ami.id
  instance_type = "t3.micro"
  key_name = var.keypair_name
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.jenkins_admin.id]
  }
  user_data = "ewogICJpZ25pdGlvbiI6IHsKICAgICJ2ZXJzaW9uIjogIjMuMS4wIgogIH0sCiAgInN5c3RlbWQiOiB7CiAgICAidW5pdHMiOiBbCiAgICAgIHsKICAgICAgICAiY29udGVudHMiOiAiW1VuaXRdXG5EZXNjcmlwdGlvbj1KZW5raW5zXG5BZnRlcj1uZXR3b3JrLW9ubGluZS50YXJnZXRcbldhbnRzPW5ldHdvcmstb25saW5lLnRhcmdldFxuXG5bU2VydmljZV1cblRpbWVvdXRTdGFydFNlYz0wXG5FeGVjU3RhcnRQcmU9LS9iaW4vcG9kbWFuIGtpbGwgamVua2luczFcbkV4ZWNTdGFydFByZT0tL2Jpbi9wb2RtYW4gcm0gamVua2luczFcbkV4ZWNTdGFydFByZT0vYmluL3BvZG1hbiBwdWxsIGplbmtpbnMvamVua2luczpsdHNcbkV4ZWNTdGFydD0vYmluL3BvZG1hbiBydW4gLS1uYW1lIGplbmtpbnMxIC1wIDUwMDAwOjUwMDAwIC1wIDgwOjgwODAgLXYgamVua2luc19ob21lOi92YXIvamVua2luc19ob21lIGplbmtpbnMvamVua2luczpsdHNcblxuW0luc3RhbGxdXG5XYW50ZWRCeT1tdWx0aS11c2VyLnRhcmdldFxuIiwKICAgICAgICAiZW5hYmxlZCI6IHRydWUsCiAgICAgICAgIm5hbWUiOiAiamVua2lucy5zZXJ2aWNlIgogICAgICB9CiAgICBdCiAgfQp9Cg=="

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "jenkins"
    }
  }

}

resource "aws_autoscaling_group" "jenkins_autoscaling_group" {
  name = "jenkins"
  max_size = 1
  min_size = 1
  launch_template {
    id = aws_launch_template.jenkins_launch_template.id
    version = "$Latest"
  }
  health_check_type = "EC2"
  wait_for_capacity_timeout = "0"
  availability_zones = data.aws_availability_zones.azs.names
}
