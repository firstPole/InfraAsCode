data "aws_subnet_ids" "subnetlist" {
  vpc_id = "${aws_vpc.main_vpc.id}"
}
