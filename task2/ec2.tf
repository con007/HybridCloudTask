provider "aws" {
  region     = "ap-south-1"
  profile    = "con" 
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDjudbn1oJBCDVw1Zq9TJbKjrF68DcVfvWIY5IkTLtifU6lcqftSQz4pUYAHOwx1MjTB88xXu1O2XmSgifMhLSaf/WPchGhDV/xubGhctNbSMGTNQ9B4VcjoXQwTq1bS5lAr9LpDk5rKOYNTw4XP5OGWUI7QHrGZVZBIOyQuARQFb4YjSH7pkceAnUlGJEwkh6phQfcagvUs6zOCOu4Lxb0zTii3S3K6qGzOotRcKNfJ+OI75CZF/bAudAMuiZYUBXi1OagGXKvTTgw1wCudPEMgPz06PldeYPjAPCClJem5WK4NNn7rOPuyJ5IcgiUyqG/qFUXzZNXUohmPibvcHVNV5X4gkqBPnYtDlcFOEBw/pBQQ1ATiwtXUebk2e2ic6+jlqf04GZQphFFPu/cXR2EBM6rq96gcpMCbmRjT6z3i1lwLKKGJbRjt4Hoo2hw7SP/lXoluR3XeIxmamvtuUvDFvEUDdrr+56ohLRL4zlsMi578SiSuv2zBOjT4L7OWvc= devops@devops-Lenovo-B590"
}


resource "aws_security_group" "MySG" {
  name        = "MySG"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-458d812d"

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

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
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

resource "aws_subnet" "mysub" {
  vpc_id  = aws_security_group.MySG.vpc_id
  availability_zone = "ap-south-1a"
  cidr_block  =  "172.31.64.0/20"
  map_public_ip_on_launch = "true"
}

resource "aws_efs_file_system" "myefs" {
depends_on = [
  aws_subnet.mysub,
]
  creation_token = "myefs"
  performance_mode = "generalPurpose"
}

resource "aws_efs_mount_target" "myefs" {
depends_on = [
  aws_efs_file_system.myefs,
] 
  file_system_id  = aws_efs_file_system.myefs.id
  subnet_id       = aws_subnet.mysub.id
  security_groups = [ aws_security_group.MySG.id ]
}


resource "aws_instance" "webserver" {
depends_on = [
  aws_efs_mount_target.myefs,
]
  ami             =  "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  subnet_id         = "${aws_subnet.mysub.id}"
  key_name        = aws_key_pair.mykey.key_name
  security_groups = [ aws_security_group.MySG.id  ]
  user_data = <<-EOF
                #! /bin/bash
                #cloud-config
                repo_update: true
                repo_upgrade: all
                sudo yum install php -y
                sudo yum install httpd -y
                sudo systemctl start httpd
                sudo systemctl enable httpd
                yum install -y amazon-efs-utils
apt-get -y install amazon-efs-utils
yum install -y nfs-utils
apt-get -y install nfs-common
file_system_id_1="${aws_efs_file_system.myefs.id}"
efs_mount_point_1="/var/www/html"
mkdir -p "$efs_mount_point_1"
test -f "/sbin/mount.efs" && echo "$file_system_id_1:/ $efs_mount_point_1 efs tls,_netdev" >> /etc/fstab || echo "$file_system_id_1.efs.ap-south-1.amazonaws.com:/ $efs_mount_point_1 nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
test -f "/sbin/mount.efs" && echo -e "\n[client-info]\nsource=liw" >> /etc/amazon/efs/efs-utils.conf
mount -a -t efs,nfs4 defaults


  EOF

  tags = {
    Name = "HybridCloudProject"
  }

}


resource "null_resource" "nullremote"  {

depends_on = [
    aws_instance.webserver,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/devops/.ssh/id_rsa1")
    host     = aws_instance.webserver.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install git -y",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/con007/HybridTerra.git /var/www/html/",
      "sudo chmod 777 /var/www/html/image/myimg.jpg"
    ]
  }
}


resource "aws_s3_bucket" "b" {

 depends_on = [
    null_resource.nullremote,
  ]

  force_destroy = true
  bucket = "my-hybrid-project-bucket"
  acl    = "public-read-write"

}


resource "null_resource" "nullremote2" {

depends_on = [
    aws_s3_bucket.b,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/devops/.ssh/id_rsa1")
    host     = aws_instance.webserver.public_ip
  }


provisioner "remote-exec" {
    inline = [
      "sudo printf '%s\n%s\nap-south-1\njson' '$key' '$secretkey' | sudo aws configure",
      "sudo aws s3 cp  --recursive /var/www/html/image s3://${aws_s3_bucket.b.bucket}/  --acl public-read",
      "sudo sed -i -e 's/image/http:\\/\\/${aws_s3_bucket.b.bucket_regional_domain_name}/g' /var/www/html/index.php",
      "sudo systemctl restart httpd"
   ]
  }
}




resource "null_resource" "nulllocal"  {


depends_on = [
    null_resource.nullremote2,
  ]

	provisioner "local-exec" {
	    command = "firefox  ${aws_instance.webserver.public_ip}"
  	}
}




resource "aws_cloudfront_distribution" "ec2_distribution" {

  depends_on = [
    null_resource.nullremote,
  ]
  origin {
    domain_name = aws_instance.webserver.public_dns
    origin_id   = "ec2Origin"
    custom_origin_config{
       http_port = "80"
       https_port = "443"
       origin_protocol_policy = "http-only"
       origin_ssl_protocols   = ["TLSv1"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true

  restrictions {
      geo_restriction {
        restriction_type = "whitelist"
        locations        = ["IN"]
     }
  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ec2Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "CloudFront"{
  value = aws_cloudfront_distribution.ec2_distribution
}

output "myouti1" {
    value = aws_instance.webserver
}

output "MySG"{
   value = aws_security_group.MySG
}
output "EFS" {
  value = aws_efs_file_system.myefs
}
