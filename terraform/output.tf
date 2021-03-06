output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}
output "public_subnet" {
  value = "${aws_subnet.public_subnet[*].id}"
}
output "sg_id" {
  value = "${aws_security_group.dynamic_sg.id}"
}

