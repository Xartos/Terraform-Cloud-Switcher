output "elb_dns_name" {
  value = "${aws_elb.my_elb.dns_name}"
}

output "vmss_public_ip" {
  value = "${azurerm_public_ip.tcspubip.fqdn}"
}

output "route53_aws_fqdn" {
  value = "${aws_route53_record.tf-aws.fqdn}"
}

output "route53_azure_fqdn" {
  value = "${aws_route53_record.tf-azure.fqdn}"
}
