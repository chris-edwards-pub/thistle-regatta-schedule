import boto3
from botocore.exceptions import ClientError
from flask import current_app


def _get_client():
    """Return a boto3 S3 client configured for Lightsail Object Storage."""
    region = current_app.config["AWS_REGION"]
    return boto3.client(
        "s3",
        region_name=region,
        endpoint_url=f"https://s3.{region}.amazonaws.com",
    )


def upload_file(file, stored_filename: str) -> None:
    """Upload a file-like object to the S3 bucket."""
    bucket = current_app.config["BUCKET_NAME"]
    client = _get_client()
    client.upload_fileobj(file, bucket, stored_filename)


def get_file_url(stored_filename: str) -> str:
    """Return a presigned URL (valid 1 hour) for downloading a file."""
    bucket = current_app.config["BUCKET_NAME"]
    client = _get_client()
    return client.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": stored_filename},
        ExpiresIn=3600,
    )


def delete_file(stored_filename: str) -> None:
    """Delete a file from the S3 bucket. Silently ignores missing files."""
    bucket = current_app.config["BUCKET_NAME"]
    client = _get_client()
    try:
        client.delete_object(Bucket=bucket, Key=stored_filename)
    except ClientError:
        pass
