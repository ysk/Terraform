#!/bin/bash
yum install -y httpd
systemctl start httpd.service
systemctl enable httpd.service --now
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent --now