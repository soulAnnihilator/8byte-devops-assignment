resource "aws_ecr_repository" "ninja" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.name
  }
}

resource "aws_ecr_lifecycle_policy" "ninja" {
  repository = aws_ecr_repository.ninja.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep a bounded number of images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_images
      }
      action = {
        type = "expire"
      }
    }]
  })
}
