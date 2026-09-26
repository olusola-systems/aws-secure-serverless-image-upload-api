# Week 30 — Secure Serverless Image Upload API

## Project Overview

In Week 30, I built a secure serverless image upload API that allows authenticated users to upload images directly to a private Amazon S3 bucket using short-lived presigned URLs.

This project extends the authentication and API security concepts from Week 29. Instead of allowing a Lambda function to receive and process the image file itself, the API generates a temporary S3 upload URL and allows the client to upload the image directly to S3.

The design reduces the amount of data flowing through the application layer while maintaining authentication, authorization, and a private storage boundary.

The upload flow is:

```text
Client
   |
   | 1. Authenticate
   v
Amazon Cognito
   |
   | 2. JWT
   v
API Gateway HTTP API
   |
   | 3. JWT Authorization
   v
Lambda
   |
   | 4. Generate presigned PUT URL
   v
Client
   |
   | 5. Direct image upload
   v
Private Amazon S3 Bucket
```

Lambda does not receive the image bytes. Its responsibility is to authenticate the request through API Gateway and generate a short-lived presigned S3 upload URL.

---

## Architecture
<img width="1774" height="887" alt="image" src="https://github.com/user-attachments/assets/cf84f11e-95b7-43bc-ab0a-56216659e4b1" />

The architecture consists of:

- Amazon Cognito for user authentication
- Amazon API Gateway HTTP API for the upload endpoint
- API Gateway JWT Authorizer for request authorization
- AWS Lambda for generating presigned S3 upload URLs
- Amazon S3 for private image storage
- Amazon CloudWatch for Lambda logging
- Terraform for infrastructure provisioning

The client first authenticates with Cognito and obtains a JWT.

The JWT is included in a request to:

```text
POST /upload-url
```

API Gateway validates the JWT before allowing the request to reach Lambda.

Lambda validates the request body, generates a unique image ID, creates an S3 object key, and generates a presigned `PUT` URL that expires after 15 minutes.

The client then uses that URL to upload the image directly to S3.

---

## Security Boundary

The security boundary is intentionally split between the API layer and the storage layer.

### API Authentication

Amazon Cognito authenticates the user and issues a JWT.

API Gateway validates the JWT before the request reaches Lambda.

Requests without a valid JWT are rejected by API Gateway.

### API Authorization

The `/upload-url` endpoint requires JWT authorization:

```text
POST /upload-url
Authorization: Bearer <JWT>
```

Requests without authentication returned:

```text
HTTP/2 401
{"message":"Unauthorized"}
```

Requests with an invalid JWT were also rejected with:

```text
HTTP/2 401
{"message":"Unauthorized"}
```

### S3 Storage

The S3 bucket is not publicly accessible.

Public access blocking is enabled for:

```text
BlockPublicAcls       = true
IgnorePublicAcls      = true
BlockPublicPolicy     = true
RestrictPublicBuckets = true
```

Objects are uploaded through temporary presigned URLs rather than public bucket access.

### Encryption

Server-side encryption is enabled by default using AES256.

```text
SSEAlgorithm: AES256
```

---

## API Endpoint

### POST /upload-url

Generates a temporary presigned S3 upload URL for an authenticated user.

### Request

```json
{
  "fileName": "Test4.png",
  "contentType": "image/png"
}
```

### Required Fields

| Field | Description |
|---|---|
| `fileName` | Name of the file being uploaded |
| `contentType` | MIME type of the file |

### Successful Response

```json
{
  "imageId": "<generated-image-id>",
  "key": "uploads/<generated-image-id>-Test4.png",
  "uploadUrl": "<presigned-url>",
  "expiresIn": 900
}
```

The presigned URL is intentionally not included in project documentation because it contains temporary signing information.

The generated upload URL expires after:

```text
900 seconds
```

or:

```text
15 minutes
```

---

## Upload Flow

The upload process consists of several steps.

### Authenticate

The client authenticates with Amazon Cognito and receives a JWT.

### Request an Upload URL

The authenticated client sends:

```http
POST /upload-url
Authorization: Bearer <JWT>
Content-Type: application/json
```

with:

```json
{
  "fileName": "Test4.png",
  "contentType": "image/png"
}
```

### Generate the Presigned URL

Lambda generates a unique image ID and creates an S3 object key:

```text
uploads/<image-id>-<file-name>
```

Lambda then generates a presigned `PUT` URL for that object.

The URL is configured to expire after 900 seconds.

### Upload Directly to S3

The client uses the presigned URL to upload the image directly to S3.

The image does not pass through Lambda.

### Verify the Object

After the upload, the object is stored in the private S3 bucket under the `uploads/` prefix.

---

## AWS Services Used

| Service | Purpose |
|---|---|
| Amazon Cognito | User authentication and JWT issuance |
| Amazon API Gateway | HTTP API and request routing |
| API Gateway JWT Authorizer | JWT validation |
| AWS Lambda | Generates presigned S3 upload URLs |
| Amazon S3 | Private image storage |
| Amazon CloudWatch | Lambda logging |
| AWS IAM | Lambda permissions |
| Terraform | Infrastructure as Code |

---

## Terraform Resources

The project provisions the following infrastructure:

```text
aws_s3_bucket
aws_s3_bucket_public_access_block
aws_s3_bucket_cors_configuration
aws_s3_bucket_server_side_encryption_configuration

aws_iam_role
aws_iam_role_policy

aws_lambda_function
aws_lambda_permission

aws_cognito_user_pool
aws_cognito_user_pool_client

aws_apigatewayv2_api
aws_apigatewayv2_stage
aws_apigatewayv2_authorizer
aws_apigatewayv2_integration
aws_apigatewayv2_route
```

The infrastructure was deployed using Terraform.

The deployment created:

```text
15 resources
```

---

## Project Structure

```text
week30-secure-serverless-image-upload-api/
│
├── lambda/
│   └── lambda_function.py
│
├── .gitignore
├── .terraform.lock.hcl
├── api_gateway.tf
├── cognito.tf
├── lambda.tf
├── outputs.tf
├── provider.tf
├── s3.tf
└── variables.tf
```

---

## Lambda Function Logic

The Lambda function receives the API Gateway request after successful JWT authorization.

The function:

1. Parses the request body.
2. Extracts `fileName`.
3. Extracts `contentType`.
4. Generates a UUID for the image.
5. Creates a unique S3 object key.
6. Generates a presigned S3 `PUT` URL.
7. Returns the URL and metadata to the client.

The presigned URL is configured with:

```python
URL_EXPIRATION = 900
```

The S3 upload operation is generated using:

```python
s3.generate_presigned_url(
    "put_object",
    Params={
        "Bucket": BUCKET_NAME,
        "Key": object_key,
        "ContentType": content_type
    },
    ExpiresIn=URL_EXPIRATION
)
```

---

## Deployment

### Initialize Terraform

```bash
terraform init
```

### Validate the Configuration

```bash
terraform validate
```

### Review the Infrastructure Plan

```bash
terraform plan
```

### Deploy the Infrastructure

```bash
terraform apply
```

Terraform created 15 resources during the Week 30 deployment.

### View Terraform Outputs

```bash
terraform output
```

Important outputs include:

```text
api_url
cognito_client_id
cognito_user_pool_id
lambda_function_name
upload_bucket_name
```

---

## Creating a Test User

I created a test Cognito user using the AWS CLI.

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password '<TEMPORARY_PASSWORD>' \
  --message-action SUPPRESS
```

I then configured a permanent password:

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --password '<TEST_PASSWORD>' \
  --permanent
```

Credentials used for testing were not committed to the repository.

---

## Authentication Testing

I authenticated the test user through Cognito and stored the returned JWT in a temporary shell variable.

The token itself was not committed to the repository or included in screenshots.

### Unauthenticated Request

A request without a JWT returned:

```text
HTTP/2 401
```

with:

```json
{
  "message": "Unauthorized"
}
```

### Invalid JWT

A request with an invalid JWT also returned:

```text
HTTP/2 401
```

API Gateway identified the token as invalid before allowing the request to reach Lambda.

### Valid JWT

A request containing the valid Cognito JWT returned:

```text
HTTP/2 200
```

and successfully generated a presigned S3 upload URL.

---

## Image Upload Testing

After receiving the presigned URL, I used it to upload a local PNG image directly to S3.

The upload returned:

```text
HTTP/1.1 200 OK
```

The object was then confirmed in S3 under:

```text
uploads/<image-id>-Test4.png
```

The test object was approximately 1.8 MB and was stored using the STANDARD S3 storage class.

This confirmed that the complete authenticated upload flow was working.

---

## S3 Security Verification

I verified the S3 Public Access Block configuration using the AWS CLI.

The bucket returned:

```json
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }
}
```

I also verified the bucket encryption configuration.

The bucket returned:

```text
SSEAlgorithm: AES256
```

This confirmed that the uploaded object was stored in an encrypted private bucket.

---

## CloudWatch Monitoring

The Lambda function writes logs to Amazon CloudWatch.

During testing, the logs included:

```text
AUTHENTICATED UPLOAD REQUEST RECEIVED
```

This confirmed that the authenticated request successfully reached Lambda after passing through API Gateway's JWT authorizer.

The Lambda logs also captured the API Gateway request event for troubleshooting and observability.

---

## Key Design Decisions

### Direct-to-S3 Uploads

I chose to use presigned S3 URLs rather than sending image data through Lambda.

This keeps Lambda focused on generating authorization for the upload instead of handling the actual file payload.

### Short-Lived Upload URLs

The presigned URLs expire after 15 minutes.

This limits the time window during which a generated upload URL can be used.

### Private S3 Storage

The bucket is intentionally private.

Clients receive temporary permission to upload to a specific S3 object rather than receiving public access to the bucket.

### JWT Authorization at API Gateway

JWT validation occurs at API Gateway before the request reaches Lambda.

This creates a clear authentication boundary and prevents unauthenticated requests from invoking the upload function.

### Terraform

The infrastructure is defined as code so that the environment can be reproduced consistently.

---

## Challenges and Troubleshooting

### Missing Terraform Archive Provider

The initial Lambda configuration used Terraform's `archive_file` data source, but the Archive provider had not yet been configured.

Terraform returned:

```text
Error: Missing required provider
```

I resolved this by adding the HashiCorp Archive provider to `provider.tf` and running:

```bash
terraform init
```

After initialization, `terraform validate` completed successfully.

### Authentication Testing

The API required separate testing for missing, invalid, and valid JWTs.

Testing these cases independently confirmed that API Gateway was enforcing the authentication boundary before allowing Lambda invocation.

### Presigned URL Testing

The presigned URL contains temporary signing information, so I kept the URL out of GitHub documentation and screenshots.

The URL was stored temporarily in a local shell variable and used only for the S3 upload test.

---

## Lessons Learned

This project helped me understand the difference between authenticating an API request and authorizing a specific action against an AWS resource. Cognito and API Gateway handled the identity and API authorization layer, while the presigned S3 URL provided temporary permission for a specific upload operation.

I also learned why direct-to-S3 uploads can be useful in serverless architectures. Instead of sending an image through API Gateway and Lambda, the application can use Lambda to generate a temporary upload URL and then transfer the file directly to S3. This keeps the application layer focused on control and authorization while S3 handles object storage.

Another important lesson was understanding how security boundaries can be layered. The API requires a valid JWT, the S3 bucket blocks public access, uploaded objects are encrypted at rest, and the presigned URL is temporary. Each layer addresses a different part of the upload workflow.

The project also reinforced the importance of testing security behavior rather than only testing successful requests. Testing missing credentials, invalid credentials, valid authentication, successful uploads, S3 access controls, and CloudWatch logging gave me evidence that the system behaved as designed.

---

## Security Considerations

The project was designed with the following security controls:

- Cognito-based authentication
- JWT authorization at API Gateway
- Private S3 bucket
- S3 Public Access Block
- Server-side encryption using AES256
- Short-lived presigned upload URLs
- IAM permissions scoped to the upload path
- No credentials committed to Git
- No presigned URLs committed to Git
- CloudWatch logging for Lambda activity

The current implementation is a development and portfolio project. A production implementation could introduce additional controls such as file type validation, file size restrictions, malware scanning, stronger object-key sanitization, rate limiting, and more restrictive CORS configuration.

---

## Future Improvements

Potential improvements include:

- Add file size validation
- Restrict accepted MIME types
- Sanitize uploaded file names
- Generate safer object keys independent of user-provided paths
- Add S3 event notifications
- Add image metadata processing
- Add malware scanning
- Add upload status tracking
- Add API throttling
- Restrict CORS to known application origins
- Add automated tests
- Add CI/CD deployment through GitHub Actions
- Add structured CloudWatch logging
- Add CloudWatch alarms and SNS notifications

---

## Outcome

I built and deployed a secure serverless image upload API using AWS and Terraform.

The completed workflow allows an authenticated client to request a short-lived upload URL and then upload an image directly to a private S3 bucket.

The project demonstrates:

- Serverless API design
- JWT authentication
- API authorization
- Presigned S3 URLs
- Private object storage
- IAM permissions
- Encryption at rest
- CloudWatch logging
- Infrastructure as Code with Terraform
- Security-focused API testing

The infrastructure was successfully deployed and tested end-to-end.

See you in week 31
