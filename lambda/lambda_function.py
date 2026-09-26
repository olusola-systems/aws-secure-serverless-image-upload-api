import json
import os
import uuid

import boto3

s3 = boto3.client("s3")

BUCKET_NAME = os.environ["BUCKET_NAME"]
URL_EXPIRATION = 900


def lambda_handler(event, context):
    print("AUTHENTICATED UPLOAD REQUEST RECEIVED")
    print(json.dumps(event))

    try:
        body = json.loads(event.get("body") or "{}")

        file_name = body.get("fileName")
        content_type = body.get("contentType")

        if not file_name or not content_type:
            return response(
                400,
                {
                    "message": "fileName and contentType are required"
                }
            )

        image_id = str(uuid.uuid4())
        object_key = f"uploads/{image_id}-{file_name}"

        upload_url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": object_key,
                "ContentType": content_type
            },
            ExpiresIn=URL_EXPIRATION
        )

        return response(
            200,
            {
                "imageId": image_id,
                "key": object_key,
                "uploadUrl": upload_url,
                "expiresIn": URL_EXPIRATION
            }
        )

    except Exception as error:
        print(f"ERROR: {str(error)}")

        return response(
            500,
            {
                "message": "Unable to generate upload URL"
            }
        )


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body)
    }
