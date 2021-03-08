#terraform {
#  backend "s3" {
#    #Be sure to match an S3 Bucket you have already created!
#    bucket = "terraform-wordpress"
#    region = "ap-south-1"
#    key    = "wordpress-app.tfstate"
#  }
#}

#######Providers#############
provider "aws" {
  region = var.AWS_REGION_NAME
}

data "aws_iam_role" "task" {
  name = var.task_role
}

#####Create IAM role###########
resource "aws_iam_role" "deployment_access_role" {
  name               = "fargate_role"
  assume_role_policy = "${file("../scripts/assumerolepolicy.json")}"
  tags = {
    Name = "fargate_role"
  }

}

#######Create IAM Policy#######
resource "aws_iam_policy" "policy" {
  name        = "fargate-policy"
  description = "a policy for deployment server"
  policy      = "${file("../scripts/ecs.json")}"
}

#######Attaching policy to role##########
resource "aws_iam_policy_attachment" "deployment-attach" {
  name       = "fargate-attachment"
  roles      = ["${aws_iam_role.deployment_access_role.name}"]
  policy_arn = "${aws_iam_policy.policy.arn}"
}



######## Create VPC ############
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.VPC_CIDR_BLOCK}"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"
  enable_classiclink   = "false"
  tags = {
    Name = "${var.project}_VPC"
  }

}
#############Create IGW######################
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "${var.project}_IGW"
  }


}


############CReate public subnet######
resource "aws_subnet" "public_subnet" {
  count                   = "${length(var.AVAILABILITY_ZONE)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${cidrsubnet(var.VPC_CIDR_BLOCK, 8, count.index)}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${element(var.AVAILABILITY_ZONE, count.index)}"
  tags = {
    Name = "${var.project}_PUB${count.index}"
  }

}


##########Create public RT#####
resource "aws_route_table" "public-rt" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
  tags = {
    Name = "${var.project}_RT"
  }
}

##############Create Public Route table Association #####################
resource "aws_route_table_association" "public-rt-association" {
  count          = "${length(var.AVAILABILITY_ZONE)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public-rt.id}"
}

########### SG ########################
resource "aws_security_group" "dynamic_sg" {
  name        = "${var.project}_sg"
  description = "clever sg"
  vpc_id      = aws_vpc.vpc.id
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  dynamic "ingress" {
    iterator = port
    for_each = var.ingress_ports
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = var.ingress_protocol
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Name = "${var.project}_sg"
  }


}

########### create efs #######
resource "aws_efs_file_system" "efs" {
  creation_token = "clever"

  tags = {
    Name = "${var.project}_EFS"
  }
}

###### create efs mount #########
resource "aws_efs_mount_target" "this" {

  file_system_id  = aws_efs_file_system.efs.id
  security_groups = [aws_security_group.dynamic_sg.id]
  subnet_id       = aws_subnet.public_subnet[0].id
}

######## create ecs cluster #######
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project}_ecs"
}

########## 
resource "aws_ecs_task_definition" "clever_task" {
  family                   = "cleverapp"
  task_role_arn            = aws_iam_role.deployment_access_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = "0.25vCPU"
  memory                   = "0.5GB"
  network_mode             = "awsvpc"
  container_definitions    = <<TASK_DEFINITION
[
    {
        
        "environment": [
            {"name": "WORDPRESS_DB_PASSWORD", "value": "wordpress"},
            {"name": "WORDPRESS_DB_USER", "value": "wordpress"},
            {"name": "WORDPRESS_DB_NAME", "value": "wordpress"},
            {"name": "WORDPRESS_DB_HOST", "value": "db:3306"}
        ],
        "essential": true,
        "mountPoints": [
                {
                    "containerPath": "/wp-content/plugins/",
                    "sourceVolume": "${var.project}-storage"
                }
            ],
        "image": "auchoudhari/wordpress-test:latest",
        "name": "app",
        "memory": 128,
        "portMappings": [
            {
                "containerPort": 80,
                "hostPort": 80
            }
        ]
        
    }
]
TASK_DEFINITION

  volume {
    name = "${var.project}-storage"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
      #root_directory = "/wp-content/plugins/"
    }
  }
}


#data "aws_ecs_task_definition" "main" {
#  task_definition = aws_ecs_task_definition.clever_task.family
#}

#####
resource "aws_ecs_service" "service" {
  name             = "cleverapp"
  cluster          = aws_ecs_cluster.ecs_cluster.id
  task_definition  = aws_ecs_task_definition.clever_task.family
  desired_count    = 1
  platform_version = "1.4.0"
  launch_type      = "FARGATE"
  network_configuration {
    security_groups  = [aws_security_group.dynamic_sg.id]
    subnets          = [aws_subnet.public_subnet[0].id]
    assign_public_ip = "true"
  }

}

#### ecs autoscalling target #####
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

######## auto scalling up policy #######
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "clever-tap-scale-up"
  policy_type        = "StepScaling"
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration {
    cooldown                = 60
    adjustment_type         = "ChangeInCapacity"
    metric_aggregation_type = "Average"
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }

  }

}

##### cloudwatch alarm #######
resource "aws_cloudwatch_metric_alarm" "high" {

  alarm_name          = "clever-alarm-high"
  alarm_description   = "Alarm monitors high utilization for scaling up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "60"
  period = "60"
  statistic           = "Average"
  alarm_actions       = [aws_appautoscaling_policy.scale_up.arn]
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  dimensions = {
    ClusterName = "${aws_ecs_cluster.ecs_cluster.name}"
  }
  insufficient_data_actions = []
  ok_actions = []
  actions_enabled = true
  datapoints_to_alarm = 1
}
