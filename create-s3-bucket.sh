#!/bin/bash

set -e
# set variable for bucket-name
BUCKET_NAME="autod-state-bucket"
DYNAMODB_TABLE="autod-state-lock"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"


# create S3 bucket

echo "Creating S3 bucket..."
aws s3api create-bucket \
 --bucket "$BUCKET_NAME" \
 --region "$AWS_REGION" \
 --profile "$AWS_PROFILE" \
 --create-bucket-configuration LocationConstraint="$AWS_REGION"
echo "S3 bucket created."


# enable S3versioning

echo "Enabling S3 versioning..."
aws s3api put-bucket-versioning \
 --bucket "$BUCKET_NAME" \
 --region "$AWS_REGION" \
 --profile "$AWS_PROFILE" \
 --versioning-configuration Status=Enabled
echo "Versioning enabled."


# Enable S3 encryption

echo "Enabling S3 encryption..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
echo "Encryption enabled."


# Block public access
echo "Blocking public access..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Public access blocked."


# Create DynamoDB table

echo "Creating DynamoDB table for state locking..."

aws dynamodb create-table \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions \
      AttributeName=LockID,AttributeType=S \
  --key-schema \
      AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"

echo "DynamoDB table created."


# 6. Wait for DynamoDB table

echo "Waiting for DynamoDB table to become active..."

aws dynamodb wait table-exists \
  --table-name "$DYNAMODB_TABLE" \
  --region "$AWS_REGION"

echo "DynamoDB table is active."



# terraform init 
# terraform validate
# terraform apply -auto-approve