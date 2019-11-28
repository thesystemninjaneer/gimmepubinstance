# =======================================================
# GIMMEPUBINSTANCE CORE COMPONENT IAC CODE RESOURCES
# =======================================================
#   Desc: This main.tf holds the definitions of all IaC
#         resources that need run prior to running
#         gimmepubinstance.tf.
#   Date: 11/27/2019
#   Author: KF
#   Dependencies:
#
#   Ex commands:
#     AWS_PROFILE=default terraform init
#                          -backend-config="bucket=$tfstatebucket" \
#                          -backend-config="key=$billingtag/create-vpc.tfstate" \
#                          -backend-config="region=$region1"
#     terraform plan
#     terraform apply
# =======================================================
provider "aws" {
  shared_credentials_file = "%HOME/.aws/credentials"
  region = "us-east-1"
}
resource "aws_s3_bucket" "gimmepubinstance" {
  bucket = "gimmepubinstance"
  acl    = "private"

  tags = {
    Name        = "gimmepubinstance"
    Environment = "Dev"
  }
}
