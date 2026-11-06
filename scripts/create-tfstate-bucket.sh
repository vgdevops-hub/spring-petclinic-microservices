#!/usr/bin/env bash
# One-time setup: creates the private, versioned, encrypted S3 bucket that holds Terraform state.
# Usage: bash scripts/create-tfstate-bucket.sh [region]      (default ap-south-1)
# Needs AWS CLI v2 configured (export AWS_PROFILE=<profile>) with an identity that can create S3 buckets.
# Works in Git Bash on Windows and on Linux/macOS.
set -euo pipefail

export MSYS_NO_PATHCONV=1   # Git Bash: stop it rewriting arguments that look like Unix paths

REGION="${1:-ap-south-1}"
# tr strips the carriage return that the Windows aws.exe adds to its output
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text | tr -d '\r')"
BUCKET="petclinic-tfstate-${ACCOUNT_ID}-${REGION}"
echo "Bucket: ${BUCKET}  Region: ${REGION}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket already exists, only re-applying settings"
elif [ "${REGION}" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
else
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
fi

# No public access, ever
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Versioning lets you recover an earlier state file
aws s3api put-bucket-versioning --bucket "${BUCKET}" --versioning-configuration Status=Enabled

# Encryption at rest
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Refuse plain-HTTP access (JSON passed inline: no temp files, so no Windows path problems)
POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::'"${BUCKET}"'","arn:aws:s3:::'"${BUCKET}"'/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}'
aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "${POLICY}"

# Keep old state versions for 90 days only (cost control)
LIFECYCLE='{"Rules":[{"ID":"expire-old-state-versions","Status":"Enabled","Filter":{},"NoncurrentVersionExpiration":{"NoncurrentDays":90}}]}'
aws s3api put-bucket-lifecycle-configuration --bucket "${BUCKET}" --lifecycle-configuration "${LIFECYCLE}"

echo
echo "Done. Create infra/bootstrap/backend.hcl with:"
echo "  bucket       = \"${BUCKET}\""
echo "  key          = \"bootstrap/terraform.tfstate\""
echo "  region       = \"${REGION}\""
echo "  encrypt      = true"
echo "  use_lockfile = true"
