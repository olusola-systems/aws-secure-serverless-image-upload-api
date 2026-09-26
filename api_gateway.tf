resource "aws_apigatewayv2_api" "upload_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  tags = {
    Name        = "${var.project_name}-api"
    Project     = var.project_name
    Environment = "development"
  }
}

resource "aws_apigatewayv2_stage" "upload_api" {
  api_id = aws_apigatewayv2_api.upload_api.id
  name   = "$default"

  auto_deploy = true
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id = aws_apigatewayv2_api.upload_api.id

  authorizer_type  = "JWT"
  authorizer_uri   = null
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-jwt-authorizer"

  jwt_configuration {
    audience = [
      aws_cognito_user_pool_client.upload_client.id
    ]

    issuer = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.upload_users.id}"
  }
}

resource "aws_apigatewayv2_integration" "upload_lambda" {
  api_id = aws_apigatewayv2_api.upload_api.id

  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload_handler.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_url" {
  api_id = aws_apigatewayv2_api.upload_api.id

  route_key = "POST /upload-url"

  target = "integrations/${aws_apigatewayv2_integration.upload_lambda.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.upload_api.execution_arn}/*/*"
}
