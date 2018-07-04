#################################################################
#   VARIABLES
#################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "network_address_space" {
  default = "10.1.0.0/16"
}

data "aws_availability_zones" "available" {}

variable "key_name" {
  default = "learnterraformvimal"
}

variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}

variable "subnet2_address_space" {
  default = "10.1.1.0/24"
}

##################################################################
# PROVIDER
##################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

#################################################################
# RESOURCES
################################################################

resource "aws_vpc" "main_vpc" {
  cidr_block           = "${var.network_address_space}"
  enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main_vpc.id}"
}

resource "aws_subnet" "primary" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.subnet1_address_space}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "secondary" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.subnet2_address_space}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.main_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = "${aws_subnet.primary.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
  subnet_id      = "${aws_subnet.secondary.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_instance" "nginx" {
  count         = 2
  ami           = "ami-00222e7b"
  instance_type = "t2.micro"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(data.aws_subnet_ids.subnetlist.ids,count.index)}"

  tags {
    Name = "First Nginx Machine"
  }

  vpc_security_group_ids = [
    "${aws_security_group.sshrules.id}",
  ]
}

resource "null_resource" "shellexecution" {
  count = 2

  triggers {
    key = "${uuid()}"
  }

  provisioner "remote-exec" {
    connection {
      user        = "ec2-user"
      host        = "${element(aws_instance.nginx.*.public_dns,count.index)}"
      private_key = "${file(var.private_key_path)}"
    }

    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Primary Server</title></head><body style=\"background-color:#534g5d\">Welcome to primary Server</body></html>'| sudo tee /usr/share/nginx/html/index.html",
    ]
  }
}

#resource "aws_elb" "nginx_elb" {
# name="${aws_elb.nginx_elb}"

#}

#################################################################
# OUTPUT
#################################################################
output "aws_instance_public_dns" {
  value = "${aws_instance.nginx.*.public_dns}"
}
