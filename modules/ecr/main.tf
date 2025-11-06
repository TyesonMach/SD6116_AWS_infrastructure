# Reusable ECR repositories set (with lifecycle to clean untagged images)
terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.repositories)
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Module = "ecr", Service = each.key })
}

resource "aws_ecr_lifecycle_policy" "untagged_cleanup" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 7 days"
      selection    = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
