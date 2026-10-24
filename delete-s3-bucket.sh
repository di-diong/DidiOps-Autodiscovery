#!/bin/bash


echo "Deleting S3 bucket"

# Using the same variables as the ones used for creation
BUCKET_NAME="autod-state-bucket"
DYNAMODB_TABLE="autod-state-lock"
AWS_REGION="eu-west-3"
AWS_PROFILE="default"

echo "Deleting all objects in $BUCKET_NAME..."

# List all object versions and delete markers
DELETE_LIST=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --output json)

# Extract objects to delete using jq
OBJECTS_TO_DELETE=$(echo "$DELETE_LIST" | jq '{
  Objects: (
    [.Versions[]?, .DeleteMarkers[]?]
    | map({Key: .Key, VersionId: .VersionId})
  ),
  Quiet: true
}')

# Count number of deletable items
NUM_OBJECTS=$(echo "$OBJECTS_TO_DELETE" | jq '.Objects | length')

# Delete objects if there are any
if [ "$NUM_OBJECTS" -gt 0 ]; then
  echo "Deleting $NUM_OBJECTS objects from bucket: $BUCKET_NAME..."

  aws s3api delete-objects \
    --bucket "$BUCKET_NAME" \
    --delete "$OBJECTS_TO_DELETE" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE"

  echo "Object deletion complete."
else
  echo "No objects or versions found in $BUCKET_NAME."
fi

# Delete bucket
echo "Deleting bucket: $BUCKET_NAME..."

aws s3api delete-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE"

echo "Bucket $BUCKET_NAME deleted successfully."

aws dynamodb delete-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE"
echo "DynamoDB table $DYNAMODB_TABLE deleted successfully."