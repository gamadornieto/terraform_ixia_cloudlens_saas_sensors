##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
#variable "aws_session_token" {}
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

variable "vpc_id" {
  description = "TF. My VPC. If empty system will create a new one"
  default     = ""
}

variable "cidr" {
  description = "TF. My CIDR"
  default     = "10.20.0.0/16"
}


variable "subnet_count" {
  default = 1
}

variable "az-subnet-mapping" {
  type        = "list"
  description = "Lists the subnets to be created in their respective AZ."

  default = [
    {
      name = "gus_subnet_1"
      az   = "us-east-1a"
      cidr = "10.20.0.0/24"
    },
    {
      name = "gus_subnet_2"
      az   = "us-east-1b"
      cidr = "10.20.1.0/24"
    },
  ]
}

##################################################################################
# PROVIDERS
##################################################################################


provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  #token  = "${var.aws_session_token}"
  region     = "us-east-1"
}


##################################################################################
# VPC
##################################################################################

locals {
  create_vpc = "${var.vpc_id == "" ? 1 : 0}"
}

data "aws_vpc" "selected" {
  count = "${1 - local.create_vpc}"
  name =  "TF_VPC_gustavo"
  id = "${var.vpc_id}"
}

resource "aws_vpc" "this" {
  count = "${local.create_vpc}"

  cidr_block = "${var.cidr}"
}

resource "aws_internet_gateway" "selected" {
  count = "${1 - local.create_vpc}"

  vpc_id = "${data.aws_vpc.selected.id}"
}

resource "aws_internet_gateway" "this" {
  count = "${local.create_vpc}"

  vpc_id = "${aws_vpc.this.id}"
}

resource "aws_subnet" "my_subnet" {
  count = "${length(var.az-subnet-mapping)}"

  cidr_block              = "${lookup(var.az-subnet-mapping[count.index], "cidr")}"
  vpc_id                  = "${aws_vpc.this.id}"
  map_public_ip_on_launch = true
  availability_zone       = "${lookup(var.az-subnet-mapping[count.index], "az")}"

  tags = {
    Name = "${lookup(var.az-subnet-mapping[count.index], "name")}"
  }
}


# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.this.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.this.id}"
  }

  tags {
    Name = "gustavo-rtb"
    BillingCode        = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }

}

resource "aws_route_table_association" "rta-subnet" {
  #count = "${var.subnet_count}"
  count = "${length(var.az-subnet-mapping)}"

  subnet_id      = "${element(aws_subnet.my_subnet.*.id,count.index)}"
  route_table_id = "${aws_route_table.rtb.id}"
}

##################################################################################
# EC2 instances
##################################################################################

resource "aws_instance" "web_srv" {
  count = "${var.num_web_srv}"

  #count = "${var.subnet_count}"
  #cidr_block = "${cidrsubnet(var.network_address_space, 8, count.index + 1)}"

  ami           = "ami-c58c1dd3"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"
  #iam_instance_profile = "${var.iam_role}"
  iam_instance_profile = "${aws_iam_instance_profile.TF_gustavo_ec2ReadOnly.name}"
  vpc_security_group_ids = ["${aws_security_group.gustavo-default-sg.id}"]

  #subnet_id =  "${element(aws_subnet.my_subnet.*.id,count.index % var.subnet_count)}"
  subnet_id =  "${element(aws_subnet.my_subnet.*.id,0)}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install docker",
      "sudo service docker start",
      "sudo systemctl enable docker",
      "sudo docker run --name ntop -v /:/host -d --restart=always --net=host --privileged ixiacom/cloudlens-sandbox-agent --server agent.ixia-sandbox.cloud --accept_eula y --apikey ${var.CL_project_key} "
    ]
  }

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
  iam_instance_profile = "${aws_iam_instance_profile.TF_gustavo_ec2ReadOnly.name}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-default-sg.id}"]

  subnet_id =  "${element(aws_subnet.my_subnet.*.id,0)}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install docker",
      "sudo service docker start",
      "sudo systemctl enable docker",
      "sudo docker run --name ntop -v /:/host -d --restart=always --net=host --privileged ixiacom/cloudlens-sandbox-agent --server agent.ixia-sandbox.cloud --accept_eula y --apikey ${var.CL_project_key} "

    ]
  }

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
  #iam_instance_profile = "${var.iam_role}"
  iam_instance_profile = "${aws_iam_instance_profile.TF_gustavo_ec2ReadOnly.name}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-ntop-sg.id}"]

  subnet_id =  "${element(aws_subnet.my_subnet.*.id,0)}"

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install docker",
      "sudo service docker start",
      "sudo systemctl enable docker",
      "sudo docker run --name ntop -v /:/host -d --restart=always --net=host --privileged ixiacom/cloudlens-sandbox-agent --server agent.ixia-sandbox.cloud --accept_eula y --apikey ${var.CL_project_key} ",
      "sudo docker run --name ntop_engine --net=host -t -p 3000:3000 -d lucaderi/ntopng-docker ntopnp -i cloudlens0"
    ]
  }

  tags {
    Name = "${var.environment_tag}-ntop1"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
    Owner = "${var.owner_tag}"
    Type = "ntop"
  }
}

##
# SECURITY GROUPS #
##



# default security group
resource "aws_security_group" "gustavo-default-sg" {
  name        = "gustavo_default_sg"
  vpc_id      = "${aws_vpc.this.id}"

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
  vpc_id      = "${aws_vpc.this.id}"

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
# IAM EC2 read only
#

resource "aws_iam_role" "TF_gustavo_ec2ReadOnly" {
  name = "TF_gustavo_ec2ReadOnly"
  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": "sts:AssumeRole",
              "Principal" : {
                "Service" : "ec2.amazonaws.com"
              },
              "Effect": "Allow"
          }
    ]
  }
EOF
}

resource "aws_iam_policy_attachment" "test-attach" {
  name       = "test-attachment"
  roles      = ["${aws_iam_role.TF_gustavo_ec2ReadOnly.name}"]
  #policy_arn = "${aws_iam_policy.policy.arn}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "TF_gustavo_ec2ReadOnly" {
  name = "TFP_gustavo_ec2ReadOnly"
  role = "${aws_iam_role.TF_gustavo_ec2ReadOnly.name}"
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_public_dns" {

    #value = [ "src1 @ ${aws_instance.web_srv.*.public_dns}" , "DB @ ${aws_instance.db.public_dns}" , "NTOP @ ${aws_instance.ntop.public_dns}:3000" ]
    value = [ "NTOP @ ${aws_instance.ntop.public_dns}:3000" ]

}
