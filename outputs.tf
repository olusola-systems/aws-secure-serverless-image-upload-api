output "api_url" {
  description = "API Gateway base URL"
  value       = aws_apigatewayv2_api.upload_api.api_endpoint
}

output "upload_bucket_name" {
  description = "Private S3 bucket used for image uploads"
  value       = aws_s3_bucket.image_uploads.bucket
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.upload_users.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.upload_client.id
}

output "lambda_function_name" {
  description = "Upload URL Lambda function name"
  value       = aws_lambda_function.upload_handler.function_name
}
