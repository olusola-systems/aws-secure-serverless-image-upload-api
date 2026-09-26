resource "aws_cognito_user_pool" "upload_users" {
  name = "${var.project_name}-users"

  username_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  tags = {
    Name        = "${var.project_name}-users"
    Project     = var.project_name
    Environment = "development"
  }
}

resource "aws_cognito_user_pool_client" "upload_client" {
  name = "${var.project_name}-client"

  user_pool_id = aws_cognito_user_pool.upload_users.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}
