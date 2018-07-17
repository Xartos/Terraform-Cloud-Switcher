variable "hosted_zone" {
  description = "Hosted zone used by Route53 (e.g. example.com)"
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

output "route53_fqdn" {
  value = "${aws_route53_record.tf.fqdn}"
}
