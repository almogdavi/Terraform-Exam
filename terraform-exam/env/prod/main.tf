module "base" {
  source = "../../modules/vpc_ec2"

  region           = "us-east-1"
  vpc_cidr         = "10.0.0.0/16"
  subnet_count     = 1
  instance_type    = "t2.micro"
  assign_public_ip = true
  key_name         = null
}
