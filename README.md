# Deploying an AWS Two-Tier Architecture using Terraform 

![image](https://user-images.githubusercontent.com/104782642/200962452-83bd3657-0920-4335-8784-fb614c22591c.png)

 
### Terraform and IaC
Infrastructure as Code is an interesting cloud concept which allows you to codify your infrastructure.
Terraform is an open-source IaC tool which uses the Hashicorp Configuration Language (HCL) to declaratively provision your infrastructure.
Unlike other IaC tools, Terraform is widely popular because it is easily adaptable, and supports multiple cloud providers.
This project describes the steps involved in using Terraform to create a two-tier AWS architecture.

**Our two-tier architecture will consist of the following:**
* A VPC
* Two public subnets for the web tier
* Two private subnets for the database tier
* A route table and security groups
* An internet gateway
* A load balancer
* Two EC2 instance, each on the public subnet
* One DB instance in one public subnet.

The project will consist of a *main.tf* file, which will contain the main terraform code, a *terraform.tfvars* file, which will contain the variables we will declare,
and an *outputs.tf* file which will return the outputs that we specify.

**Prerequisites:**
* AWS account with programmatic access
* AWS CLI
* Terraform CLI
* Text editor or IDE


#### Step 1: Create a *main.tf* file
I'm using an ubuntu linux machine for this project, and I've created a project directory called aws-two-tier. I'm creating a *main.tf* file inside this folder using 
the *vim* text editor. Next we create the terraform block in the *main.tf* file, where we specify the terraform providers and version requirements. We also need to create the provider block, where we specify the cloud provider and the region. Our resources will be created in the "eu-west-2" London region.

```HCL
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
```

#### Step 2: Create a *terraform.tfvars* file 
Next I declared our list of variables in the *main.tf* file. Because this is a small project, I'm only going to list one variable which is the project name. 
This is because I prefer to include the project name when assigning the name-tag attribute to my resources. That way you can easily identify which resources belong to which project.

```HCL
# Create a list of variables
variable project_name {}
```

Then I created a *terraform.tfvars* file in the same project directory to define the variable which I have just listed.

```HCL
project_name = "two-tier"
```

#### Step 3: Create the VPC and Subnets.
We continue on the *main.tf* file and define the configuration to create the one VPC and four subnets in two availability zones, with the cidr block configuration below: 
  
VPC = 10.0.0.0/16  
Public Subnet 1 = 10.0.1.0/24  
Public Subnet 2 = 10.0.2.0/24  
Private Subnet 1 = 10.0.3.0/24  
Private Subnet 2 = 10.0.4.0/25  
```HCL
# Create a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "${var.project_name}-vpc"
  }
}

# Create 2 public subnets
resource "aws_subnet" "pub-sub-1" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.project_name}-public-subnet-1"
  }
}

resource "aws_subnet" "pub-sub-2" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.project_name}-public-subnet-2"
  }
}

# Create 2 private subnets 
resource "aws_subnet" "priv-sub-1" {
  cidr_block = "10.0.3.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = false
  tags = {
    "Name" = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "priv-sub-2" {
  cidr_block = "10.0.4.0/24"
  vpc_id = aws_vpc.vpc.id
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = false
  tags = {
    "Name" = "${var.project_name}-private-subnet-2"
  }
}
```

#### Step 4: Create an Internet Gateway and Route Table
Here we are creating an internet gateway and a route table to route internet traffic to the VPC. And we will associate only the public subnets which will contain the web tier to the route table.

``` HCL
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
  subnet_id = aws_subnet.pub-sub-1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "public-rtb-2" {
  subnet_id = aws_subnet.pub-sub-2.id
  route_table_id = aws_route_table.rtb.id
  ```
  
  #### Step 5: Create Security Groups
  In this step we are creating a public security group to allow HTTP and SSH traffic to the VPC. And also a private security group that allows traffic only from the web-tier security group. 
  *Note that ideally we shoud only allow SSH traffic from trusted devices or IP address, however for this project I'm allowing SSH traffic to the web-tier from all IP addresses, i.e 0.0.0.0/0.
 
 ```HCL
 # Create public security group
resource "aws_security_group" "pub-sg" {
  name = "pub-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Allow web and ssh"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    "Name" = "${var.project_name}-pub-sg"
  }
}

# Create private security group
resource "aws_security_group" "priv-sg" {
  name = "priv-sg"
  vpc_id = aws_vpc.vpc.id
  description = "Allow web tier and ssh"

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    security_groups = [ aws_security_group.pub-sg.id ]
  }

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "${var.project_name}-priv-sg"
  }
  ```
#### Step 6: Create a Load Balancer
In this step we create an application load balancer, to balance the traffic on our we-tier. We need a security group for the load balancer, and we also need to 
define the target group and create target attachements.

```HCL
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
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
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
```
#### Step 7: Create EC2 instances
We are creating our EC2 instance using the amazon linux image, but first we need to fetch the latest AWS ami. Next we create two EC2 instances with the ami we just fetched, in two availability zones using an existing keypair which I called "UbuntuX". We also want this EC2 instances to install Apache Web Server and run a simple HTML code, so we define this in the *user_data*. 
  
*Note: it is also possible to create an entirely new key-pair from the configuration, which will be used to SSH into the EC2 instance. And we can also pass a bash script file to the user_data, to get it to configure whatever we want on the EC2 instances. But we are keeping it simple for this project, so I'm using an existing key and also passing the bash command directly to the user_data*

```HCL
# Fetch the latest EC2 ami from amazon
data "aws_ami" "latest_amazon_linux_image" {
  most_recent = true
  owners = ["137112412989"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

#create the EC2 instance using amazon image
resource "aws_instance" "web-server-1" {
  ami = data.aws_ami.latest_amazon_linux_image.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub-sub-1.id
  vpc_security_group_ids = [aws_security_group.pub-sg.id]
  availability_zone = "eu-west-2a"
  associate_public_ip_address = true
  key_name = "TF-key"
    user_data = <<-EOF
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
  ami = data.aws_ami.latest_amazon_linux_image.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub-sub-2.id
  vpc_security_group_ids = [aws_security_group.pub-sg.id]
  availability_zone = "eu-west-2b"
  associate_public_ip_address = true
  key_name = "TF-key"
    user_data = <<-EOF
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
```

#### Step 8: Create a DB instance
To create a db instance, we need to create a db subnet group which is linked to our private subnets. Then we configure our MySQL db engine.

```HCL
# Create Database subnet group
resource "aws_db_subnet_group" "db-sub"  {
    name       = "db-subnet"
    subnet_ids = [aws_subnet.priv-sub-1.id, aws_subnet.priv-sub-2.id]
}

# Create database instance
resource "aws_db_instance" "mysqldb" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  identifier           = "db-instance"
  db_name              = "mysqldb"
  username             = "admin"
  password             = "password"
  db_subnet_group_name = aws_db_subnet_group.db-sub.id
  vpc_security_group_ids = [aws_security_group.priv-sg.id]  
  publicly_accessible = false
  skip_final_snapshot  = true
  ```
  
#### Step 9: Create *outpus.tf* file
Because we want to be able access the resources we are creating without having to go through the AWS console, we will need some information to access these resources. 
These are called outputs, and they can be configured in the outputs.tf file in the same project directory. The information we need will be displayed after the resources has been deployed by terraform.

```HCL
# Outputs
# Ec2 instance public ipv4 address
output "ec2_public_ip" {
  value = aws_instance.web-server-1.public_ip
}

# Db instance address
output "db_instance_address" {
    value = aws_db_instance.mysqldb.address
}

# Getting the DNS of load balancer
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = "${aws_lb.project_alb.dns_name}"
}
```

#### Step 10: Terraform init
Now that the configuration is complete, we need to initiate terraform with the *terraform init* command. This will initialize the terraform backend and download the required plugins for the provider version we are working with. 

![image](https://user-images.githubusercontent.com/104782642/200569518-009fbe78-a268-495f-acd4-ac8c9bae81d5.png)

We also need to run *terraform fmt* commannd to format our code to make it more readable and easier for collaboration.

![image](https://user-images.githubusercontent.com/104782642/200570744-1c5dccd0-d288-4b1a-b3e8-fc6b3a3bc67a.png)


#### Step 11: Terraform plan
We will run the *terraform plan* command to show us the action plan, i.e. which changes are going to be made, otherwise in this case, which resources are going to be deployed.  
Here we can see that 21 resources will be created, and details of our output will be known after apply.

![image](https://user-images.githubusercontent.com/104782642/200601204-27be287e-3e64-487f-9a80-1099578ea92a.png)

#### Step 12: Terraform apply
Finally we can create our resources by running the *terraform apply* command. This command deploys the resources we have configured into AWS, and also prompts terraform to configure the *terraform.tfstate* file which is used to manage the state of our resources. We will  be prompted to confirm the action by typing "yes".

![image](https://user-images.githubusercontent.com/104782642/200923037-adda764f-0bdf-4886-86ee-c61a1f48e052.png)

#### Step 13: Confirm our resources
First I tried to confirm if I can SSH into the EC2 instance that I just created using the existing keypair. And yes, I can securely SSH into the server.
![image](https://user-images.githubusercontent.com/104782642/200924413-15e25149-2d6e-4f8a-abe5-91a1fcac2b1e.png)

Next I used the DNS name of the load balancer, which we can get from the output to confirm if we can access our web servers from the internet. And yes we can. The load balancer is also balancing traffic between both servers.

![image](https://user-images.githubusercontent.com/104782642/200933700-43bc7210-f700-4a5a-a187-4c1b8d748341.png)
![image](https://user-images.githubusercontent.com/104782642/200933805-31058991-dfe1-4699-aab1-8e2a1a061917.png)


**I also logged in to the console to view our resources**

![image](https://user-images.githubusercontent.com/104782642/200942619-b16acddb-1581-4a70-bbe3-e81d66b226ea.png)

![image](https://user-images.githubusercontent.com/104782642/200942868-fb56afaf-5c07-413b-9469-aeccb540c482.png)

![image](https://user-images.githubusercontent.com/104782642/200943069-31f7e465-4605-461a-8570-a3fb7f237387.png)

![image](https://user-images.githubusercontent.com/104782642/200943259-b048c0ce-ab58-4f2b-81a1-db59f39c1c64.png)

![image](https://user-images.githubusercontent.com/104782642/200943496-ec9654be-8cd9-4439-b1e6-1f918547a833.png)

![image](https://user-images.githubusercontent.com/104782642/200944042-11b6a9f2-1bf3-4666-987a-ec9b0d1f89bd.png)

![image](https://user-images.githubusercontent.com/104782642/200944354-126f0717-0163-4672-809d-9bfd41368da5.png)

![image](https://user-images.githubusercontent.com/104782642/200944717-be256a25-a2df-405f-89a9-5ea49b1f7cc4.png)

#### Step 14: Terraform destroy
And finally we will use *terraform destroy* command to destroy the resources we created. This is very straighforward, it will delete every resources that is being tracked in the *terraform.tfstate* file. 

![image](https://user-images.githubusercontent.com/104782642/200946452-6e0ff23b-4436-43ee-832a-0f21a9950958.png)

*End!*




