provider "aws" {
  region = "eu-west-3"
}

variable "group_size" {
  description = "Number of VMs in the cloudpool"
  default     = 2
}

variable "server_port" {
  description = "Server HTTP request port"
  default     = 80
}

variable "hosted_zone" {
  description = "Hosted zone used by Route53 (e.g. example.com)"
}

data "aws_availability_zones" "available" {}

resource "aws_launch_configuration" "my_launch_configuration" {
  image_id        = "ami-20ee5e5d"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello world! My name is" `hostname`"." > index.html
    nohup busybox httpd -f -p "${var.server_port}" &
    EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "my_autoscaling_group" {
  launch_configuration = "${aws_launch_configuration.my_launch_configuration.id}"
  min_size             = "${var.group_size}"
  max_size             = "${var.group_size}"
  availability_zones   = ["${data.aws_availability_zones.available.names}"]

  load_balancers    = ["${aws_elb.my_elb.name}"]
  health_check_type = "ELB"

  tag = {
    key                 = "Name"
    value               = "my-terraform-asg"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" {
  name = "my-terraform-security-group"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb" {
  name = "my-terraform-elb"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "my_elb" {
  name               = "my-terraform-lb"
  security_groups    = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.available.names}"]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 60
    target              = "HTTP:${var.server_port}/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }
}

data "aws_route53_zone" "primary" {
  name         = "${var.hosted_zone}"
  private_zone = false
}

resource "aws_route53_record" "tf" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "tf"
  type    = "CNAME"
  ttl     = 60

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "tf"
  records        = ["${aws_elb.my_elb.dns_name}"]
}

output "elb_dns_name" {
  value = "${aws_elb.my_elb.dns_name}"
}

output "route53_fqdn" {
  value = "${aws_route53_record.tf.fqdn}"
}
