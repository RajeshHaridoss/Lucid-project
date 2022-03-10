################################ create VPC and its resources############

# one vpc to hold them all, and in the cloud bind them

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"

  tags { 
     Name = "vpc for demo"    
  }
}

# create internet gateway to talk to internet

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags { 
     Name = "IGW for demo" 
  }  
}


#Create 1 public subnet per availablitliy zone

resource "aws_subnet" "public" {
  availability_zone       = "${element(var.availability_zones,count.index)}"
  cidr_block              = "${element(var.public_subnets_cidr,count.index)}"
  count                   = "${length(var.availability_zones)}"
  map_public_ip_on_launch = true
  vpc_id                  = "${aws_vpc.main.id}"
  tags {
    Name = "subnet-pub-${count.index}"
  }
}

# dynamic list of the public subnets created above
data "aws_subnet_ids" "public" {
  depends_on = [aws_subnet.public]
  vpc_id     = "${aws_vpc.main.id}"
}


# main route table for vpc and subnets
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "public_route_table_main"
  }
}

# add public internet gateway to the route table
resource "aws_route" "public" {
  gateway_id             = "${aws_internet_gateway.igw.id}"
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.public.id}"
}


# associate route table with vpc
resource "aws_main_route_table_association" "public" {
  vpc_id         = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# associate route table with each subnet
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = "${element(data.aws_subnet_ids.public.ids, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}


# create one private subnet per availability zone 

resource "aws_subnet" "private" {
  availability_zone       = "${element(var.availability_zones,count.index)}"
  cidr_block              = "${element(var.private_subnets_cidr,count.index)}"
  count                   = "${length(var.availability_zones)}"
  map_public_ip_on_launch = true
  vpc_id                  = "${aws_vpc.main.id}"
  tags {
    Name = "subnet-priv-${count.index}"
  }
}


# dynamic list of the private subnets created above
data "aws_subnet_ids" "private" {
  depends_on = ["aws_subnet.private"]
  vpc_id     = "${aws_vpc.main.id}"
}


# create elastic IP (EIP) to assign it the NAT Gateway 
resource "aws_eip" "demo_eip" {
  count    = "${length(var.availability_zones)}"
  vpc      = true
  depends_on = ["aws_internet_gateway.igw"]
}


# create NAT Gateways
# make sure to create the nat in an internet-facing subnet (public subnet)
resource "aws_nat_gateway" "demo" {
    count    = "${length(var.availability_zones)}"
    allocation_id = "${element(aws_eip.demo_eip.*.id, count.index)}"
    subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
    depends_on = ["aws_internet_gateway.igw"]
}

# for each of the private ranges, create a "private" route table.
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"
  count ="${length(var.availability_zones)}" 
  tags { 
    Name = "private_subnet_route_table_${count.index}"
  }
}

# add a nat gateway to each private subnet's route table
resource "aws_route" "private_nat_gateway_route" {
  count = "${length(var.availability_zones)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  depends_on = ["aws_route_table.private"]
  nat_gateway_id = "${element(aws_nat_gateway.demo.*.id, count.index)}"
}



####Create Application load balancer and its resources#####################

# security group for application load balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "allow incoming HTTP traffic only"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "alb-security-group"
  }
}

# using ALB - instances in private subnets
resource "aws_alb" "main_alb" {
  name                      = "main-alb"
  security_groups           = ["${aws_security_group.alb_sg.id}"]
  subnets                   = ["${aws_subnet.private.*.id}"]
  tags {
    Name = "main-alb"
  }
}

# alb target group
resource "aws_alb_target_group" "demo-tg" {
  name     = "demo-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
  health_check {
    path = "/"
    port = 80
  }
}

# listener
resource "aws_alb_listener" "http_listener" {
  load_balancer_arn = "${aws_alb.main_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.demo-tg.arn}"
    type             = "forward"
  }
}

# target group attach
resource "aws_lb_target_group_attachment" "http" {
  count = "${length(aws_instance.app_server)}"
  target_group_arn = "${aws_alb_target_group.demo-tg.arn}"
  target_id = aws_instance.app_server[count.index].id
  port = 80
}

# ALB DNS is generated dynamically, return URL so that it can be used
output "url" {
  value = "http://${aws_alb.main_alb.dns_name}/"
}

# Route53 record for DNS entry
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.dns_name}"
  type    = "A"

  alias {
    name                   = aws_alb.main_alb.dns_name
    zone_id                = aws_alb.main_alb.zone_id
    evaluate_target_health = true
  }
}

##############Create Web servers and it's resources##############################

#Create security group for the web server
resource "aws_security_group" "ec2_sg" {
  name = "Ec2 security group"
  description = "Allow Incoming http traffic only"
  vpc_id      = "${aws_vpc.main.id}"


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

  tags = {
         Name = var.name 
  }
      
}


# EC2 instances, one per availability zone
resource "aws_instance" "app_server" {
  ami                         = "${lookup(var.ec2_amis, var.aws_region)}"
  associate_public_ip_address = true
  count                       = "${length(var.availability_zones)}"
  depends_on                  = ["aws_subnet.private"]
  instance_type               =  var.instance_type
  subnet_id                   = "${element(aws_subnet.private.*.id,count.index)}"
  user_data                   = "${file("user_data.sh")}"

  # references security group created above
  vpc_security_group_ids = ["${aws_security_group.ec2_sg.id}"]

  tags {
    Name = "nginx-instance-${count.index}"
  }
}



## CREATE AUTO SCALING LAUNCH CONFIG 

resource "aws_launch_configuration" "ec2" {
  image_id               = "${lookup(var.ec2_amis, var.aws_region)}"
  instance_type          = var.instance_type
  security_groups        = "${aws_security_group.ec2_sg.id}"
  user_data              = "${file("user_data.sh")}"
  lifecycle {
    create_before_destroy = true
  }
}

## Creating AutoScaling Group#####

resource "aws_autoscaling_group" "ec2_asg" {
  name                 = "demo-autoscaling-group"
  launch_configuration = "${aws_launch_configuration.ec2.id}"
  min_size = 1
  max_size = 6
  desired_capacity = 2
  target_group_arns = "${aws_alb_target_group.demo-tg.arn}"
  vpc_zone_identifier  = "${aws_subnet.private.*.id}"
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "ec2-asg"
    propagate_at_launch = true
  }
}


# scale up cloudwatch alarm
resource "aws_autoscaling_policy" "demo-cpu-policy" {
	name = "demo-cpu-policy"
	autoscaling_group_name = "${aws_autoscaling_group.ec2_asg.name}"
	adjustment_type = "ChangeInCapacity"
	scaling_adjustment = "1"
	cooldown = "300"
	policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "demo-cpu-alarm" {
	alarm_name = "demo-cpu-alarm"
	alarm_description = "demo-cpu-alarm"
	comparison_operator = "GreaterThanOrEqualToThreshold"
	evaluation_periods = "2"
	metric_name = "CPUUtilization"
	namespace = "AWS/EC2"
	period = "120"
	statistic = "Average"
	threshold = "60"   
	dimensions = {
		"AutoScalingGroupName" = "${aws_autoscaling_group.ec2_asg.name}"
	}
	actions_enabled = true
	alarm_actions = ["${aws_autoscaling_policy.demo-cpu-policy.arn}"]
}


# scale down alarm
resource "aws_autoscaling_policy" "demo-cpu-policy-scaledown" {
	name = "demo-cpu-policy-scaledown"
	autoscaling_group_name = "${aws_autoscaling_group.ec2_asg.name}"
	adjustment_type = "ChangeInCapacity"
	scaling_adjustment = "-1"
	cooldown = "300"
	policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "demo-cpu-alarm-scaledown" {
	alarm_name = "demo-cpu-alarm-scaledown"
	alarm_description = "demo-cpu-alarm-scaledown"
	comparison_operator = "LessThanOrEqualToThreshold"
	evaluation_periods = "2"
	metric_name = "CPUUtilization"
	namespace = "AWS/EC2"
	period = "120"
	statistic = "Average"
	threshold = "50"
	dimensions = {
		"AutoScalingGroupName" = "${aws_autoscaling_group.ec2_asg.name}"
	}
	actions_enabled = true
	alarm_actions = ["${aws_autoscaling_policy.demo-cpu-policy-scaledown.arn}"]
}



#######create RDS instances and connections ##############################


resource "aws_security_group" "rds_security_group" {
  name        = "rds_security_group"
  description = "rds security group"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "rds_security_group"
  }
}

resource "aws_db_instance" "db" {
  engine            = "${var.rds_engine}"
  engine_version    = "${var.rds_engine_version}"
  identifier        = "${var.rds_identifier}"
  instance_class    = "${var.rds_instance_type}"
  allocated_storage = "${var.rds_storage_size}"
  name              = "${var.rds_db_name}"
  username          = "${var.rds_admin_user}"
  password          = "${var.rds_admin_password}"
  publicly_accessible    = "${var.rds_publicly_accessible}"
  db_subnet_group_name   = "${aws_db_subnet_group.rds_test.id}"
  vpc_security_group_ids = ["${aws_security_group.rds_security_group.id}"]
  final_snapshot_identifier = "demo-db-backup"
  skip_final_snapshot       = true

  tags {
    Name = "Postgres Database in ${var.aws_region}"
  }
}

resource "aws_db_subnet_group" "rds_test" {
  name       = "rds_test"
  subnet_ids    = "${aws_subnet.private.*.id}"
  tags = {
    Name = "DB Subnet Group"
  }
}

output "postgress-address" {
  value = "address: ${aws_db_instance.db.address}"
}

