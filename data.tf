## The current AWS account ID and region 
data "aws_caller_identity" "current" {}

## The current AWS region
data "aws_region" "current" {}
