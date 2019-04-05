##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_session_token" {
  default = ""
}
variable "private_key_path" {}
variable "key_name" {}
variable "iam_role" {}

variable "CL_project_key" {}

variable "billing_code_tag" {}
variable "environment_tag" {}
variable "owner_tag" {}
variable "tag_type" {
  default = "db"
}

variable "num_web_srv" {
  default = 1
}
variable "num_db" {
  default = 1
}

##################################################################################
# PROVIDERS
##################################################################################


provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  token  = "${var.aws_session_token}"
  region     = "us-east-1"
}

##################################################################################
# Declare User Data templates
##################################################################################

data "template_file" "userdata_ubuntu_cl_sensor" {
  template = "${file("templates/ubuntu_cl_sensor.sh")}"
  vars {
    cl_project_key   = "${var.CL_project_key}"
  }
}

data "template_file" "userdata_add_ntop" {
  template = "${file("templates/add_ntop.sh")}"
}

data "template_file" "userdata_ubuntu_add_tcpdump" {
  template = "${file("templates/ubuntu_add_tcpdump.sh")}"
}

data "template_file" "userdata_generate_http_dns" {
template = "${file("templates/generate_http_dns.sh")}"
}


##################################################################################
# RESOURCES VMs
##################################################################################

resource "aws_instance" "web_srv" {
  count = "${var.num_web_srv}"

  #count = "${var.subnet_count}"
  #cidr_block = "${cidrsubnet(var.network_address_space, 8, count.index + 1)}"

  ami           = "ami-c58c1dd3"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"

  iam_instance_profile = "${var.iam_role}"
  #iam_instance_profile = "${aws_iam_instance_profile.gustavo_example.name}"
  vpc_security_group_ids = ["${aws_security_group.gustavo-default-sg.id}"]


  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_ubuntu_cl_sensor.rendered} ${data.template_file.userdata_generate_http_dns.rendered} "

  tags {
    Name = "${var.environment_tag}-web-srv${count.index}"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
    Type = "web_srv"
    Owner = "${var.owner_tag}"
  }
}


resource "aws_instance" "db" {
  count = "${var.num_db}"

  ami           = "ami-c58c1dd3"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"

  iam_instance_profile = "${var.iam_role}"
  #iam_instance_profile = "${aws_iam_instance_profile.gustavo_example.name}"
  vpc_security_group_ids = ["${aws_security_group.gustavo-default-sg.id}"]

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_ubuntu_cl_sensor.rendered}"

  tags {
    Name = "${var.environment_tag}-db${count.index}"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
    Owner = "${var.owner_tag}"
    Type = "db"
  }
}


resource "aws_instance" "ntop" {
  ami           = "ami-c58c1dd3"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"

  iam_instance_profile = "${var.iam_role}"
  #iam_instance_profile = "${aws_iam_instance_profile.gustavo_example.name}"
  vpc_security_group_ids = ["${aws_security_group.gustavo-ntop-sg.id}"]

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_ubuntu_cl_sensor.rendered} ${data.template_file.userdata_add_ntop.rendered}"

  tags {
    Name = "${var.environment_tag}-ntop1"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
    Owner = "${var.owner_tag}"
    Type = "ntop"
  }
}

resource "aws_instance" "tcpdump" {
  ami           = "ami-c58c1dd3"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"


  iam_instance_profile = "${var.iam_role}"
  #iam_instance_profile = "${aws_iam_instance_profile.gustavo_example.name}"
  vpc_security_group_ids = ["${aws_security_group.gustavo-default-sg.id}"]

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_ubuntu_cl_sensor.rendered} ${data.template_file.userdata_ubuntu_add_tcpdump.rendered} "

  tags {
    Name = "${var.environment_tag}-tcpdump1"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
    Owner = "${var.owner_tag}"
    Type = "tcpdump"
  }
}

##
# SECURITY GROUPS #
##

# default security group

#  egress {
#    from_port   = 19993
#    to_port     = 19993
#    protocol    = "udp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

# default security group
resource "aws_security_group" "gustavo-default-sg" {
  name        = "gustavo_default_sg"
  #vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.environment_tag}-gustavo_ntop-sg"
    BillingCode        = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# security group for NTOP
resource "aws_security_group" "gustavo-ntop-sg" {
  name        = "gustavo_ntop_sg"
  #vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.environment_tag}-gustavo_ntop-sg"
    BillingCode        = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

#
# IAM EC2 read only. Not creating IAM role since Ixia SE account does not allow it.
# Just using predefined iam_instance_profile



##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_public_dns" {

    #value = [ "src1 @ ${aws_instance.web_srv.*.public_dns}" , "DB @ ${aws_instance.db.public_dns}" , "NTOP @ ${aws_instance.ntop.public_dns}:3000" ]
    value = [ "NTOP @ ${aws_instance.ntop.public_dns}:3000" ]
}
