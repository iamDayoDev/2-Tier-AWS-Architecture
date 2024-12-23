#VPC Configuration
resource "aws_vpc" "main-vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "main-VPC"
  }
}

# Public Subnet 1
resource "aws_subnet" "Public1" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 1"
  }
}

# Public Subnet 2
resource "aws_subnet" "Public2" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 2"
  }
}

# Private Subnet 1
resource "aws_subnet" "Private1" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 1"
  }
}

# Private Subnet 2
resource "aws_subnet" "Private2" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 2"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main-vpc.id
}

#Elastic IP
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

#NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.Public1.id
  depends_on    = [aws_eip.nat_eip]
}

#Route Tables
resource "aws_route_table" "Public_Route" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "Private_Route" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}


# Public Route Subnet Association
# Public Subnet 1
resource "aws_route_table_association" "Public1" {
  subnet_id      = aws_subnet.Public1.id
  route_table_id = aws_route_table.Public_Route.id
}

# Public Subnet 2
resource "aws_route_table_association" "Public2" {
  subnet_id      = aws_subnet.Public2.id
  route_table_id = aws_route_table.Public_Route.id
}


# Private Route Subnet Association
# Private Subnet 1
resource "aws_route_table_association" "Private1" {
  subnet_id      = aws_subnet.Private1.id
  route_table_id = aws_route_table.Private_Route.id
}

# Private Subnet 2
resource "aws_route_table_association" "Private2" {
  subnet_id      = aws_subnet.Private2.id
  route_table_id = aws_route_table.Private_Route.id
}

# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = aws_vpc.main-vpc.id


  ingress {
    description = "http proxy access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow access on port 22
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Docker server security group"
  }
}


# use data source to get a registered amazon linux 2 ami
data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# launch the ec2 instance and install website
resource "aws_instance" "apache-server-1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Public1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "key_login"

  tags = {
    Name = "apache-server-1"
  }

  user_data = <<-EOF
    #!/bin/bash

# Update all packages on the server
sudo apt update -y

# Install Apache web server (apache2 for Ubuntu)
sudo apt install apache2 -y

# Start Apache web server
sudo systemctl start apache2

# Enable Apache to start automatically on system boot
sudo systemctl enable apache2

# Create a simple "It works!" webpage
echo "It works!" | sudo tee /var/www/html/index.html

# Restart Apache to ensure the page is served
sudo systemctl restart apache2


    EOF

}

resource "aws_instance" "apache-server-2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Public2.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "key_login"

  tags = {
    Name = "apache-server-2"
  }

  user_data = <<-EOF
    #!/bin/bash

# Update all packages on the server
sudo apt update -y

# Install Apache web server (apache2 for Ubuntu)
sudo apt install apache2 -y

# Start Apache web server
sudo systemctl start apache2

# Enable Apache to start automatically on system boot
sudo systemctl enable apache2

# Create a simple "It works!" webpage
echo "It works!" | sudo tee /var/www/html/index.html

# Restart Apache to ensure the page is served
sudo systemctl restart apache2


    EOF

}

#RDS Instance Security Group
#Configure a security group for the RDS instance that will be deployed in the private subnets

resource "aws_security_group" "RDS_SG" {
  name        = "RDS_SG"
  description = "Allows inbound MySQL traffic and allows all outbound traffic from the RDS instance"
  vpc_id      = aws_vpc.main-vpc.id

  tags = {
    Name = "RDS-TF-SG"
  }

  # Create Ingress Rule to allow inbound MySQL traffic from the Web server security group
  ingress {
    security_groups = [aws_security_group.ec2_security_group.id]
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
  }
  # Create Egress Rule to allow all outbound traffic from the RDS instance
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}


#Subnet Group
#Create a subnet group for the database tier to launch the RDS instance

resource "aws_db_subnet_group" "RDS_subnet_group" {
  name       = "rds-db"
  subnet_ids = [aws_subnet.Private1.id, aws_subnet.Private2.id]

  tags = {
    Name = "My DB subnet group"
  }
}


#RDS Instance
#Deploy the RDS instance in the private subnets as specified during the configuration of the subnet group

resource "aws_db_instance" "RDS_instance" {
  allocated_storage      = 10
  db_name                = "myrds"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "dayo"
  password               = "Mypassword"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.RDS_subnet_group.id
  vpc_security_group_ids = [aws_security_group.RDS_SG.id]
}