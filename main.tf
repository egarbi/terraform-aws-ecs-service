/**
 * The service module creates an ecs service, task definition
 * This module is intended to use with a target_group created
 * externally and passed as an argument.
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source       = "git::ssh://git@bitbucket.org/ldfrtm/stack//service"
 *        name      = "auth-service"
 *        cluster   = "default"
 *      }
 *
 */

/**
 * Required Variables.
 */

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "container_port" {
  description = "The container port"
  default     = 8080
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "container_definitions" {
  description = "here you should include the full container definitons"
}

variable "target_group" {
  description = "Target Groups will be created with the ALB"
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

resource "aws_ecs_service" "main" {
  name            = "${var.name}"
  cluster         = "${var.cluster}"
  task_definition = "${module.task.arn}"
  desired_count   = "${var.desired_count}"
  iam_role        = "${var.iam_role}"
  
  placement_strategy {
    type = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type = "binpack"
    field = "cpu"
  }

  placement_strategy {
    type = "binpack"
    field = "memory"
  }

  load_balancer {
    target_group_arn = "${var.target_group}"
    container_name   = "${var.name}_app"
    container_port   = "${var.container_port}"
  }
}

module "task" {
  source                = "git::https://github.com/egarbi/terraform-aws-task-definition"
  name                  = "${var.name}-${var.environment}"
  task_role             = "${aws_iam_role.main.arn}"
  container_definitions = "${var.container_definitions}"
}

// The task role name used by the task definition
output "task_role" {
  value = "${aws_iam_role.main.name}"
}

// The task role arn used by the task definition
output "task_role_arn" {
  value = "${aws_iam_role.main.arn}"
}
