provider "aws" {
  region     = "ap-south-1"
  profile    = "con" 
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDjudbn1oJBCDVw1Zq9TJbKjrF68DcVfvWIY5IkTLtifU6lcqftSQz4pUYAHOwx1MjTB88xXu1O2XmSgifMhLSaf/WPchGhDV/xubGhctNbSMGTNQ9B4VcjoXQwTq1bS5lAr9LpDk5rKOYNTw4XP5OGWUI7QHrGZVZBIOyQuARQFb4YjSH7pkceAnUlGJEwkh6phQfcagvUs6zOCOu4Lxb0zTii3S3K6qGzOotRcKNfJ+OI75CZF/bAudAMuiZYUBXi1OagGXKvTTgw1wCudPEMgPz06PldeYPjAPCClJem5WK4NNn7rOPuyJ5IcgiUyqG/qFUXzZNXUohmPibvcHVNV5X4gkqBPnYtDlcFOEBw/pBQQ1ATiwtXUebk2e2ic6+jlqf04GZQphFFPu/cXR2EBM6rq96gcpMCbmRjT6z3i1lwLKKGJbRjt4Hoo2hw7SP/lXoluR3XeIxmamvtuUvDFvEUDdrr+56ohLRL4zlsMi578SiSuv2zBOjT4L7OWvc= devops@devops-Lenovo-B590"
}


resource "aws_vpc" "lwtask3" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "lwtask3"
  }
}

resource "aws_subnet" "sub-1a" {

depends_on = [
  aws_vpc.lwtask3,
]

  vpc_id     = "${aws_vpc.lwtask3.id}"
  availability_zone = "ap-south-1a"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "sub-1a"
  }
}

resource "aws_subnet" "sub-1b" {

depends_on = [
  aws_subnet.sub-1a,
]

  vpc_id     = "${aws_vpc.lwtask3.id}"
  availability_zone = "ap-south-1b"
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "sub-1b"
  }
}

resource "aws_internet_gateway" "myigw" {

depends_on = [
  aws_subnet.sub-1b,
]

  vpc_id = "${aws_vpc.lwtask3.id}"

  tags = {
    Name = "lwtask3"
  }
}


resource "aws_route_table" "lwtask3" {

depends_on = [
  aws_internet_gateway.myigw,
]

  vpc_id = "${aws_vpc.lwtask3.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myigw.id}"
  }

  tags = {
    Name = "lwtask3"
  }
}

resource "aws_route_table_association" "a" {

depends_on = [
  aws_route_table.lwtask3,
]

  subnet_id      = "${aws_subnet.sub-1a.id}"
  route_table_id = aws_route_table.lwtask3.id
}



resource "aws_security_group" "MySG" {

depends_on = [
  aws_route_table_association.a,
]

  name        = "MySG"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.lwtask3.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 80 
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
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
    Name = "MySG"
  }
}

resource "aws_security_group" "bastion" {

depends_on = [
  aws_route_table_association.a,
]


  name        = "bastion"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.lwtask3.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BastionSG"
  }
}

resource "aws_security_group" "MySGPri" {

depends_on = [
  aws_route_table_association.a,
]


  name        = "MySGPri"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.lwtask3.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups  = [aws_security_group.MySG.id]
  }
 
  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySGPriv"
  }
}

resource "aws_instance" "wordpress" {
depends_on = [
  aws_security_group.MySG,
]
  ami               =  "ami-7e257211"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  subnet_id         = "${aws_subnet.sub-1a.id}"
  key_name          = aws_key_pair.mykey.key_name
  security_groups   = [ aws_security_group.MySG.id  ]
  
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/home/devops/.ssh/id_rsa1")
    host        = aws_instance.wordpress.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i -e 's/aurora/admin/g' /var/www/wordpress/wp-config.php",
      "sudo sed -i -e 's/${aws_instance.wordpress.id}/$password/g' /var/www/wordpress/wp-config.php",
    ]
  }


  tags = {
    Name = "Wordpress"
  }
}


resource "aws_instance" "bastion" {
depends_on = [
  aws_security_group.bastion,
]
  ami               =  "ami-0732b62d310b80e97"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  subnet_id         = "${aws_subnet.sub-1a.id}"
  key_name          = aws_key_pair.mykey.key_name
  security_groups   = [ aws_security_group.bastion.id ]
  
  tags = {
    Name = "Bation Host"
  }

}

resource "aws_instance" "mysql" {
depends_on = [
  aws_security_group.MySGPri,
]
  ami               = "ami-09cb94e5c3c51b17a"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1b"
  subnet_id         = "${aws_subnet.sub-1b.id}"
  key_name          = "mysql"
  security_groups   = [ aws_security_group.MySGPri.id  ]

  tags = {
    Name = "MySQL"
  }

}


resource "null_resource" "nullremote1" {

depends_on = [
    aws_instance.mysql,
  ]

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file("/home/devops/.ssh/id_rsa")
    host     = aws_instance.wordpress.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo sed -i -e 's/localhost/${aws_instance.mysql.private_ip}/g' /var/www/wordpress/wp-config.php",
   ]
  }

}

resource "aws_eip" "nat" {
  vpc              = true
 }


resource "aws_nat_gateway" "lwtask3" {

depends_on = [
  aws_instance.mysql,
]

  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.sub-1a.id}"

  tags = {
    Name = "lwtask3 NAT"
  }
}


resource "aws_route_table" "lwtask3nat" {

depends_on = [
  aws_nat_gateway.lwtask3,
]

  vpc_id = "${aws_vpc.lwtask3.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.lwtask3.id}"
  }

  tags = {
    Name = "lwtask3"
  }
}

resource "aws_route_table_association" "nat" {

depends_on = [
  aws_route_table.lwtask3nat,
]

  subnet_id      = "${aws_subnet.sub-1b.id}"
  route_table_id = aws_route_table.lwtask3nat.id
}



