terraform {
  backend "s3" {
    bucket         = "tf-state-my-jenkins"
    key            = "web/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


##### NETWORKING
resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "jenkins_subnet" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_internet_gateway" "jenkins_igw" {
  vpc_id = aws_vpc.jenkins_vpc.id
}

resource "aws_route_table" "jenkins_route_table" {
  vpc_id = aws_vpc.jenkins_vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.jenkins_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.jenkins_igw.id
}

resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.jenkins_subnet.id
  route_table_id = aws_route_table.jenkins_route_table.id
}

resource "aws_security_group" "jenkins_sg" {
  name   = "jenkins-sg"
  vpc_id = aws_vpc.jenkins_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


##### ECR Access from EC2
resource "aws_iam_policy" "ecr_pull_policy" {
  name = "ECR-Pull-Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      }
    ],
  })
}

resource "aws_iam_role" "ecr_role" {
  name = "ECR-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      }
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecr_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecr_pull_policy.arn
  role       = aws_iam_role.ecr_role.name
}

resource "aws_iam_instance_profile" "ecr_instance_profile" {
  name = "ECR-Instance-Profile"
  role = aws_iam_role.ecr_role.name
}


##### EC2
resource "aws_instance" "jenkins_instance" {
  ami           = "ami-08a52ddb321b32a8c"
  instance_type = "t2.small"
  key_name      = "aaron-aws"
  subnet_id     = aws_subnet.jenkins_subnet.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ecr_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install docker -y
              sudo service docker start
              sudo usermod -a -G docker ec2-user

              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 806152608109.dkr.ecr.us-east-1.amazonaws.com
              docker pull 806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
              
              docker network create jenkins

              docker run \
                --name jenkins-docker \
                --rm \
                --detach \
                --privileged \
                --network jenkins \
                --network-alias docker \
                --env DOCKER_TLS_CERTDIR=/certs \
                --volume jenkins-docker-certs:/certs/client \
                --volume jenkins-data:/var/jenkins_home \
                --publish 2376:2376 \
                docker:dind \
                --storage-driver overlay2

              docker run \
                --name jenkins-blueocean \
                --restart=on-failure \
                --detach \
                --network jenkins \
                --env DOCKER_HOST=tcp://docker:2376 \
                --env DOCKER_CERT_PATH=/certs/client \
                --env DOCKER_TLS_VERIFY=1 \
                --publish 8080:8080 \
                --publish 50000:50000 \
                --volume jenkins-data:/var/jenkins_home \
                --volume jenkins-docker-certs:/certs/client:ro \
                806152608109.dkr.ecr.us-east-1.amazonaws.com/my-jenkins:2.414.1-1
              EOF
}

output "instance_public_ip" {
  value = aws_instance.jenkins_instance.public_ip
}

