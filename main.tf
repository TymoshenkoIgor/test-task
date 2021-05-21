#Create VPC
resource "aws_vpc" "test-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags = {
    Name = "test-vpc"
  }
}

#Create subnet for instance-a
resource "aws_subnet" "subnet-1a" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet-1a"
  }
}

#Create subnet for instance-b
resource "aws_subnet" "subnet-1b" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet-1b"
  }
}

#Create Internet gateway
resource "aws_internet_gateway" "test-gw" {
  vpc_id = aws_vpc.test-vpc.id
  tags = {
    Name = "test-gw"
  }
}

#Add Route table for using  gateway
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.test-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-gw.id
  }

  tags = {
    Name = "public-rt"
  }
}

#Associate route table with subnet-1a to make it public
resource "aws_route_table_association" "rta_1a_public" {
  subnet_id      = aws_subnet.subnet-1a.id
  route_table_id = aws_route_table.public-rt.id
}

#Associate route table with subnet-1b to make it public
resource "aws_route_table_association" "rta_1b_public" {
  subnet_id      = aws_subnet.subnet-1b.id
  route_table_id = aws_route_table.public-rt.id
}

#Gathering all subnets ids in current vpc
data "aws_subnet_ids" "test" {
  vpc_id = aws_vpc.test-vpc.id

  depends_on = [
    aws_subnet.subnet-1a,
    aws_subnet.subnet-1b
  ]
}

#Crerate instance-a with eu-central-1a
resource "aws_instance" "instance-a" {
  # ami = "ami-07fc7611503eb6b29"
  ami = "ami-086d0be14ab5129e1" #Microsoft Windows Server 2019 Base
  #key_name               = "terraform-key"
  instance_type          = "t2.nano"
  availability_zone      = "eu-central-1a"
  subnet_id              = aws_subnet.subnet-1a.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "igor"
  get_password_data      = "true"

  tags = {
    Name = "instance-a"
  }
}

#Crerate instance-a with eu-central-1b
resource "aws_instance" "instance-b" {
  # ami = "ami-07fc7611503eb6b29"
  ami = "ami-086d0be14ab5129e1" #Microsoft Windows Server 2019 Base
  #key_name               = "terraform-key"
  instance_type          = "t2.nano"
  availability_zone      = "eu-central-1b"
  subnet_id              = aws_subnet.subnet-1b.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = "igor"
  get_password_data      = "true"

  tags = {
    Name = "instance-b"
  }
}

#Create security group
resource "aws_security_group" "instance" {
  name   = "http-instance"
  vpc_id = aws_vpc.test-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create Network Load Balancer
resource "aws_lb" "test" {
  name               = "test-load-balancer"
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.test.ids
}

#Create Network Load Balancer with port 80
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.test.arn

  protocol = "TCP"
  port     = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}

#Create target group for listeners
resource "aws_lb_target_group" "instances" {
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.test-vpc.id
  target_type = "instance"

  depends_on = [
    aws_lb.test
  ]
}

#Attach  instance-a to target group
resource "aws_lb_target_group_attachment" "tg-instance-a" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance-a.id
  port             = 80
}

#Attach  instance-b to target group
resource "aws_lb_target_group_attachment" "tg-instance-b" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance-b.id
  port             = 80
}

output "Public_IPs" {
   value = {
     instance_a = aws_instance.instance-a.public_ip,
     instance_b = aws_instance.instance-b.public_ip
   }
}

output "Administrator_Password" {
   value = {
     instance_a = rsadecrypt(aws_instance.instance-a.password_data,file("igor.pem")),
     instance_b = rsadecrypt(aws_instance.instance-b.password_data,file("igor.pem"))
   }
}