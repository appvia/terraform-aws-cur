
locals {
  ## Current AWS account ID and region
  account_id = data.aws_caller_identity.current.account_id
  # If region is not provided, use the current region
  region = var.region != "" ? var.region : data.aws_region.current.name
  ## Common tags merged with specific tags
  tags = merge(var.tags, {})
}
