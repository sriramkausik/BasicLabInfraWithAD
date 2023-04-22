//Author Sriram and KiranRaj

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    } 
  }
}


provider "aws" {
  region = "us-east-1"
  access_key = "AKIA5EBBOPTNFMFH7QDF"
  secret_key = "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"
}

resource "aws_vpc" "VPCFROMTF" {
  cidr_block = "10.0.0.0/16" 
  tags = {
        Name = "TFVPC"
  }
}

  resource "aws_subnet" "SUBNETONEFROMTF" {
    cidr_block = var.Subnet1
    availability_zone = "us-east-1a" 
    vpc_id= aws_vpc.VPCFROMTF.id
  tags = {
        Name = "TFSUBNET"
  }
    
  }
resource "aws_subnet" "SUBNETFROMTF" {
  cidr_block = var.Subnet
  availability_zone = "us-east-1b" 
  vpc_id= aws_vpc.VPCFROMTF.id
  tags = {
        Name = "TFSUBNET"
  }
  
}

resource "aws_internet_gateway" "IGWFROMTF" {
  #Name="IGWFROMTF"
  vpc_id = aws_vpc.VPCFROMTF.id

  tags = {
    "name" = "TFIGW"
  }
  
}


//Create a simple AD
resource "aws_directory_service_directory" "bar" {
  name     = "India.com"
  password = "Travel@2020"
  size     = "Small"

  vpc_settings {
    vpc_id     = aws_vpc.VPCFROMTF.id
    subnet_ids = [aws_subnet.SUBNETONEFROMTF.id, aws_subnet.SUBNETFROMTF.id]
  }

  tags = {
    Project = "SimpleAD"
  }
}

//Create a IAM role with 3 policy attached.



resource "aws_iam_role" "ec2-ssm-role" {
name = "EC2SSMROLE"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "AmazonSSMFullAccess" {
  role       = aws_iam_role.ec2-ssm-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMDirectoryServiceAccess" {
  role       = aws_iam_role.ec2-ssm-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.ec2-ssm-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2-ssm-role" {
  name = "ec2-ssm-role"
  role = aws_iam_role.ec2-ssm-role.name
}

//Create an EC2 instance

resource "aws_instance" "EC2FROMTF" {
  #name="EC2FROMTF"
  ami = "ami-0bde1eb2c18cb2abe"
  subnet_id = aws_subnet.SUBNETFROMTF.id
  iam_instance_profile = aws_iam_instance_profile.ec2-ssm-role.name
  instance_type = "t2.micro"
  associate_public_ip_address = true

  tags ={
  name="TFEC2"
}
}

//Domain Join
resource "aws_ssm_document" "ssm_document" {
  name          = "ssm_document_example.com"
  document_type = "Command"
  content       = <<DOC
{
    "schemaVersion": "1.0",
    "description": "Automatic Domain Join Configuration",
    "runtimeConfig": {
        "aws:domainJoin": {
            "properties": {
                "directoryId": "${aws_directory_service_directory.bar.id}",
                "directoryName": "India.com",
                "dnsIpAddresses": ${jsonencode(aws_directory_service_directory.bar.dns_ip_addresses)}
            }
        }
    }
}
DOC
}

resource "aws_ssm_association" "associate_ssm" {
  name        = aws_ssm_document.ssm_document.name
 
  targets {
    key    = "InstanceIds"
    values = [aws_instance.EC2FROMTF.id]
  }
}

//SG group :

resource "aws_security_group" "allow_full" {
  name        = "allow_full"
  description = "Full open"
  vpc_id      = aws_vpc.VPCFROMTF.id

  ingress {
    description      = "allow_full"
    from_port        = 0
    to_port          = 0
    protocol         = -1
      cidr_blocks      = ["0.0.0.0/0"]
  }
    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    tags = {
    Name = "allow_All"
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.allow_full.id
  network_interface_id = aws_instance.EC2FROMTF.primary_network_interface_id
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.VPCFROMTF.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGWFROMTF.id
  }

  tags = {
    Name = "RT"
  }
}


resource "aws_route_table_association" "RTA" {
  subnet_id      = aws_subnet.SUBNETFROMTF.id
  route_table_id = aws_route_table.RT.id
}




