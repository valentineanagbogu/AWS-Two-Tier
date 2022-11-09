terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.38"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

# Create a list of variables
variable "project_name" {}

# Create a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "${var.project_name}-vpc"
  }
}

# Create 2 public subnets
resource "aws_subnet" "pub-sub-1" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.project_name}-public-subnet-1"
  }
}

resource "aws_subnet" "pub-sub-2" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.project_name}-public-subnet-2"
  }
}

# Create 2 private subnets 
resource "aws_subnet" "priv-sub-1" {
  cidr_block              = "10.0.3.0/24"
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = false
  tags = {
    "Name" = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "priv-sub-2" {
  cidr_block              = "10.0.4.0/24"
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = false
  tags = {
    "Name" = "${var.project_name}-private-subnet-2"
  }
}


# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "${var.project_name}-igw"
  }
}

# Create a route table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = "${var.project_name}-rtb"
  }
}

# Associate public subnets with route table
resource "aws_route_table_association" "public-rtb-1" {
  subnet_id      = aws_subnet.pub-sub-1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "public-rtb-2" {
  subnet_id      = aws_subnet.pub-sub-2.id
  route_table_id = aws_route_table.rtb.id
}

# Create public security group
resource "aws_security_group" "pub-sg" {
  name        = "pub-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "Allow web and ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    "Name" = "${var.project_name}-pub-sg"
  }
}

# Create private security group
resource "aws_security_group" "priv-sg" {
  name        = "priv-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "Allow web tier and ssh"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]
    security_groups = [aws_security_group.pub-sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "${var.project_name}-priv-sg"
  }

}

# Create security group for ALB
resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "ALB - SG"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "${var.project_name}-alb-sg"
  }
}

# Create ALB
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.pub-sub-1.id, aws_subnet.pub-sub-2.id]
  tags = {
    "Name" = "${var.project_name}-alb"
  }

}

# Create ALB target group
resource "aws_lb_target_group" "alb-tg" {
  name       = "alb-tg"
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]
  tags = {
    "Name" = "${var.project_name}-alb-tg"
  }
}

# Create target attachments
resource "aws_lb_target_group_attachment" "tg-att-1" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id        = aws_instance.web-server-1.id
  port             = 80

  depends_on = [aws_instance.web-server-1]
}

resource "aws_lb_target_group_attachment" "tg-att-2" {
  target_group_arn = aws_lb_target_group.alb-tg.arn
  target_id        = aws_instance.web-server-2.id
  port             = 80

  depends_on = [aws_instance.web-server-2]
}

# Create listener
resource "aws_lb_listener" "listener-alb" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}

# Fetch the latest EC2 ami from amazon
data "aws_ami" "latest_amazon_linux_image" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#create the EC2 instance using amazon image
resource "aws_instance" "web-server-1" {
  ami                         = data.aws_ami.latest_amazon_linux_image.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.pub-sub-1.id
  vpc_security_group_ids      = [aws_security_group.pub-sg.id]
  availability_zone           = "eu-west-2a"
  associate_public_ip_address = true
  key_name                    = "TF-key"
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hello Server 1</h1></body></html>" > /var/www/html/index.html
        EOF
  tags = {
    "Name" = "${var.project_name}-web-server-1"
  }
}

resource "aws_instance" "web-server-2" {
  ami                         = data.aws_ami.latest_amazon_linux_image.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.pub-sub-2.id
  vpc_security_group_ids      = [aws_security_group.pub-sg.id]
  availability_zone           = "eu-west-2b"
  associate_public_ip_address = true
  key_name                    = "TF-key"
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hello Server 2</h1></body></html>" > /var/www/html/index.html
        EOF
  tags = {
    "Name" = "${var.project_name}-web-server-2"
  }
}


# Create Database subnet group
resource "aws_db_subnet_group" "db-sub" {
  name       = "db-subnet"
  subnet_ids = [aws_subnet.priv-sub-1.id, aws_subnet.priv-sub-2.id]
}

# Create database instance
resource "aws_db_instance" "mysqldb" {
  allocated_storage      = 5
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  identifier             = "db-instance"
  db_name                = "mysqldb"
  username               = "admin"
  password               = "password"
  db_subnet_group_name   = aws_db_subnet_group.db-sub.id
  vpc_security_group_ids = [aws_security_group.priv-sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

