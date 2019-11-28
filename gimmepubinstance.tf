# Author: thesystemninjaneer@gmail.com
# Date: 11/27/19
# License: GPL
# Desc:
#  This terraform module can be run via ~/.bashrc alias "gimmepubinstance"
#  Assuming an
#    1. aws account,
#    2. S3 bucket (gimmepubinstance), and
#    3. local ssh priv/pub key (~/.ssh/id_rsa & ~/.ssh/id_rsa.pub)
#  already exists, it will create all other resources necessary
#  to spin up a publicly accessible instance in AWS.

variable "myip" {
  description = "e.g. output of 'curl checkip.amazonaws.com'"
}
variable "awsprofile" {
  description = "if you have multiple aws credentials set in your AWS cli"
}

provider "aws" {
  shared_credentials_file = "%HOME/.aws/credentials"
  region = "us-east-1"
}

#must run .gimmepubinstance/runfirst/main.tf before to create below bucket
terraform {
  backend "s3" {
    bucket = "gimmepubinstance"
    key = "terraform.tfstate"
    region = "us-east-1"
  }
}

# based on https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html and https://medium.com/@brad.simonin/create-an-aws-vpc-and-subnet-using-terraform-d3bddcbbcb6
resource "aws_vpc" "gimmevpc" {
  cidr_block       = "10.100.0.0/16"

  tags = {
    Name = "gimmevpc"
  }
} #aws_vpc

resource "aws_subnet" "gimmesubnetpub1" {
  vpc_id     = "${aws_vpc.gimmevpc.id}"
  cidr_block = "10.100.100.0/24"

  tags = {
    Name = "gimmesubnetpub1"
  }
} #aws_subnet

resource "aws_internet_gateway" "gimmegw" {
  vpc_id = "${aws_vpc.gimmevpc.id}"

  tags = {
    Name = "gimmegw"
  }
} #aws_internet_gateway

resource "aws_route_table" "gimmeroutetable" {
  vpc_id = "${aws_vpc.gimmevpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gimmegw.id}"
  }

  tags = {
    Name = "gimmeroutetable"
  }
} #aws_route_table

resource "aws_route_table_association" "gimmerouteassoc" {
  subnet_id      = "${aws_subnet.gimmesubnetpub1.id}"
  route_table_id = "${aws_route_table.gimmeroutetable.id}"
} #aws_route_table_association

resource "aws_network_acl" "gimmeaclinbound" {
  vpc_id = "${aws_vpc.gimmevpc.id}"
  subnet_ids = ["${aws_subnet.gimmesubnetpub1.id}"]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${var.myip}"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 310
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name = "gimmeacl"
  }
} #aws_network_acl

resource "aws_security_group" "sshext" {
  name        = "ssh-from-gimme-${var.myip}"
  description = "ssh from gimme ${var.myip}"
  vpc_id = "${aws_vpc.gimmevpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.myip}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
} #aws_security_group

# based on https://ifritltd.com/2017/12/06/provisioning-ec2-key-pairs-with-terraform/
resource "aws_key_pair" "gimmekeypair" {
  key_name = "gimmekeypair"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
  #if above doesnt exist, may need this: ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
} #aws_key_pair

resource "aws_iam_role" "gimmeiamrole" {
  name = "gimmeiamrole"
  description = "allow gimmepubinstance to access some resources in the gimme vpc"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "gimmeiamrole"
  }
} #aws_iam_role

resource "aws_iam_policy" "gimmepubinstancepolicy" {
  name        = "gimmepubinstancepolicy"
  description = "gimmepubinstancepolicy policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAccessForBucket",
      "Effect": "Allow",
      "Action": [
        "s3:List*",
        "s3:Get*",
        "s3:Put*"
      ],
      "Resource": [
        "arn:aws:s3:::gimmepubinstance",
        "arn:aws:s3:::gimmepubinstance/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "gimmeiamprofile" {
  name = "gimmeiamprofile"
  role = "${aws_iam_role.gimmeiamrole.name}"
} #aws_iam_instance_profile

resource "aws_iam_role_policy_attachment" "gimmeiamattach" {
  role       = "${aws_iam_role.gimmeiamrole.name}"
  policy_arn = "${aws_iam_policy.gimmepubinstancepolicy.arn}"
}



data "aws_ami" "centos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS ENA *"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"] # centos vendor
} #aws_ami

resource "aws_spot_instance_request" "gimmepubinstance" {

  ami = "${data.aws_ami.centos.id}"  #filtered value from "aws_ami" section above
  instance_type = "t3a.micro"
  key_name = "gimmekeypair"
  associate_public_ip_address = true
  spot_type = "one-time"
  vpc_security_group_ids = [
    aws_security_group.sshext.id
  ]
  block_duration_minutes = "300"
  subnet_id = "${aws_subnet.gimmesubnetpub1.id}"
  iam_instance_profile = "gimmeiamprofile"
  root_block_device {
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  # bug: tags for spot not supported
  tags = {
    Name = "gimmepubinstance"
  }
  # workaround
  wait_for_fulfillment = true
  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${aws_spot_instance_request.gimmepubinstance.spot_instance_id} --tags Key=Name,Value=gimmepubinstance --region us-east-1 --output text --profile ${var.awsprofile}"
  }

} #aws_spot_instance_request

data "aws_instances" "gimmespot" {
  filter {
    name = "tag:Name"
    values = ["gimmepubinstance"]
  }
  depends_on = ["aws_spot_instance_request.gimmepubinstance"]
} #aws_instances

output "gimmepubinstance_ip" {
  value = "${data.aws_instances.gimmespot.public_ips}"
}

output "gimmepubinstance_id" {
  value = aws_spot_instance_request.gimmepubinstance.id
}

output "gimmepubinstance_sgid" {
  value = aws_security_group.sshext.id
}
