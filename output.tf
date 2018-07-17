output "elb_dns_name" {
  value = "${aws_elb.my_elb.dns_name}"
}

output "route53_fqdn" {
  value = "${aws_route53_record.tf.fqdn}"
}
