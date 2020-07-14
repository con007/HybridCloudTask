provider "aws" {
  region     = "ap-south-1"
  profile    = "<profile name set by aws configure --profile <name> >" 
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = "<Your id_rsa.pub / public key>"
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


resource "aws_instance" "webserver" {
  ami             =  "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.mykey.key_name
  security_groups = [ "MySG"  ] 
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/devops/.ssh/id_rsa1")
    host        = aws_instance.webserver.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "HybridCloudProject"
  }

}

resource "aws_ebs_volume" "ebs_t1" {
  availability_zone = aws_instance.webserver.availability_zone
  size              = 1

  tags = {
    Name = "myebst1"
  }
}

resource "aws_volume_attachment" "ebst1_attach" {
  device_name  = "/dev/sdd"
  volume_id    = aws_ebs_volume.ebs_t1.id
  instance_id  = aws_instance.webserver.id
  force_detach = true
}


resource "null_resource" "nullremote"  {

depends_on = [
    aws_volume_attachment.ebst1_attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/devops/.ssh/id_rsa1")
    host     = aws_instance.webserver.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
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
      "sudo printf '%s\n%s\nap-south-1\njson' '<Access Key>' '<Secret Access Key>' | sudo aws configure",
      "sudo aws s3 cp  --recursive /var/www/html/image s3://${aws_s3_bucket.b.bucket}/  --acl public-read",
      "sudo sed -i -e 's/image/http:\\/\\/${aws_s3_bucket.b.bucket_regional_domain_name}/g' /var/www/html/index.php",
      "sudo systemctl restart httpd"
   ]
  }
}



output "myout" {
    value = aws_s3_bucket.b
}

output "myouti1" {
    value = aws_instance.webserver.public_dns
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
