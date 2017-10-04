AWS Task Definition Terraform module
========================

Terraform module which creates a simple task-definition to be used with ECS services

Usage
-----

```hcl
module "task" {
  source                = "git::https://github.com/egarbi/terraform-aws-task-definition"
  name            = "example"
  environment     = "testing"
  desired_count   = "1"
  cluster         = "example-cluster"
  iam_role        = "arn:aws:iam::123203969087:role/ec2_role"
  target_group    = "arn:aws:elasticloadbalancing:eu-west-1:12345678910:targetgroup/example-testing/xxxxxxxxxxxx"
  container_definitions = "${file("container_definitions.json")}"
}
```
The referenced `container_definitions.json` file contains a valid JSON document, which is shown below, and its content is going to be passed directly into the container_definitions attribute as a string. Please note that this example contains only a small subset of the available parameters.
```
[
  {
    "name": "first",
    "image": "service-first",
    "cpu": 10,
    "memory": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  },
  {
    "name": "second",
    "image": "service-second",
    "cpu": 10,
    "memory": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ]
  }
]

```
