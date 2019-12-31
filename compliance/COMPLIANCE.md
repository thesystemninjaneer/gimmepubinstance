# Install Tools

This was derived from https://sysadvent.blogspot.com/2019/12/day-18-generating-compliance-as-code.html. To keep your laptop clean, these instructions assume you have docker installed so all steps can be executed within a CentOS 8 container. It also assumes your laptop already has the AWS CLI installed with your AWS credentials configured within `$HOME/.aws`.

## Windows laptop

1. Run a fresh centos 8 container
```
docker run -ti -v "//$HOME/.aws:/root/.aws" centos:8 bash
```
1. install AWS cli
```
yum install -y python3
pip3 install awscli --upgrade --user
export PATH=$PATH:/root/.local/bin
```
1. download the latest inspec RPM from https://downloads.chef.io/inspec/stable
```
curl -k https://packages.chef.io/files/stable/inspec/4.18.51/el/8/inspec-4.18.51-1.el7.x86_64.rpm -O
yum install -y inspec-4.18.51-1.el7.x86_64.rpm
```
2. Install the aws resource pack for inspec
```
```
