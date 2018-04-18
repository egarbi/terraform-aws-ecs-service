/**
 * Required Variables.
 */

variable "name" {
  description = "The service name"
}

variable "cluster" {
  description = "The cluster name"
}

variable "vpc_id" {
  description = "The VPC ID were the ECS is running"
}

variable "zone_id" {
  description = "Zone ID where the ECS service (record) will be added"
}

variable "container_definitions" {
  description = "here you should include the full container definitions"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "alb_listener" {
  description = "Listener where the rule will be added"
}

variable "alb_dns_name" {
  description = "DNS name of the ALB where the rule will be added"
}

variable "alb_zone_id" {
  description = "Zone ID where the ALB is hosted"
}

variable "rule_priority" {
  description = "This is the priority number of the listener's rule"
}

/**
 * Optional Variables.
 */

variable "environment" {
  description = "Environment tag, e.g prod"
  default     = "default"
}

variable "container_port" {
  description = "The container port"
  default     = 8080
}

variable "healthcheck" {
  default = {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    path                = "/health"
    interval            = 30
    matcher             = 200
  }
}

variable "desired_count" {
  description = "The desired count"
  default     = 1
}

variable "policy" {
  description = "IAM custom policy to be attached to the task role"
  default     = ""
}

variable "cookie_duration" {
  description = "The time period, in seconds, during which requests from a client should be routed to the same target.The range is 1 second to 1 week (604800 seconds)"
  default     = "86400"
}

variable "stick_enabled" {
  description = "Boolen to enable / disable stickiness"
  default     = "false"
}

/* * Resources.
 */

// Task Role could be useful to grant special permissions 
// conveniently to the containers running into
resource "aws_iam_role" "main" {
  name = "${var.name}-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "main" {
  count = "${var.policy == "" ? 0 : 1}"

  name   = "${var.name}-${var.environment}"
  role   = "${aws_iam_role.main.id}"
  policy = "${var.policy}"
}

resource "aws_alb_target_group" "main" {
  name         = "${var.name}-${var.environment}"
  port         = "${var.container_port}"
  protocol     = "HTTP"
  vpc_id       = "${var.vpc_id}"
  health_check = ["${var.healthcheck}"]
  stickiness {
    type            = "lb_cookie"
    cookie_duration = "${var.cookie_duration}"
    enabled         = "${var.stick_enabled}"
  }
}

resource "aws_alb_listener_rule" "main" {
  listener_arn = "${var.alb_listener}"
  priority     = "${var.rule_priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.main.arn}"
  }

  condition {
    field  = "host-header"
    values = ["${var.name}.*"]
  }
}

resource "aws_ecs_service" "main" {
  name            = "${var.name}"
  cluster         = "${var.cluster}"
  task_definition = "${module.task.arn}"
  desired_count   = "${var.desired_count}"
  iam_role        = "${var.iam_role}"

  placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    container_name   = "${var.name}_app"
    container_port   = "${var.container_port}"
  }
}

module "task" {
  source                = "git::https://github.com/egarbi/terraform-aws-task-definition?ref=1.0.0"
  name                  = "${var.name}-${var.environment}"
  task_role             = "${aws_iam_role.main.arn}"
  container_definitions = "${var.container_definitions}"
}

// Add ALB record on DNS
resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.name}"
  type    = "A"

  alias {
    name                   = "${var.alb_dns_name}"
    zone_id                = "${var.alb_zone_id}"
    evaluate_target_health = false
  }
}

output "task_role" {
  description = "The task role name used by the task definition"
  value       = "${aws_iam_role.main.name}"
}

output "task_role_arn" {
  description = "The task role arn used by the task definition"
  value       = "${aws_iam_role.main.arn}"
}

// It has proven be useful to be used as input for other modules
output "target_group" {
  description = "The target group name created by this module"
  value       = "${aws_alb_target_group.main.name}"
}

output "target_group_arn_suffix" {
  description = "The target group suffix to use as input on alarms"
  value       = "${aws_alb_target_group.main.arn_suffix}"
}
