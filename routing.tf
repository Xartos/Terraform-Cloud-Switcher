data "aws_route53_zone" "primary" {
  name         = "${var.hosted_zone}"
  private_zone = false
}

resource "aws_route53_health_check" "hs-aws" {
  fqdn              = "${aws_elb.my_elb.dns_name}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "2"
  request_interval  = "30"

  tags = {
    Name = "tf-aws-health-check"
  }
}

resource "aws_route53_health_check" "hs-azure" {
  fqdn              = "${azurerm_public_ip.tcspubip.fqdn}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "2"
  request_interval  = "30"

  tags = {
    Name = "tf-azure-health-check"
  }
}

resource "aws_route53_record" "tf-aws" {
  zone_id         = "${data.aws_route53_zone.primary.zone_id}"
  name            = "tf"
  type            = "CNAME"
  ttl             = 30
  health_check_id = "${aws_route53_health_check.hs-aws.id}"

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "aws"
  records        = ["${aws_elb.my_elb.dns_name}"]
}

resource "aws_route53_record" "tf-azure" {
  zone_id         = "${data.aws_route53_zone.primary.zone_id}"
  name            = "tf"
  type            = "CNAME"
  ttl             = 30
  health_check_id = "${aws_route53_health_check.hs-azure.id}"

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "azure"
  records        = ["${azurerm_public_ip.tcspubip.fqdn}"]
}
