#!/usr/bin/env bash
# One-time setup: creates the private, versioned, encrypted S3 bucket that holds Terraform state.
# Usage: bash scripts/create-tfstate-bucket.sh [region]      (default ap-south-1)
# Needs AWS CLI v2 configured with an identity that can create S3 buckets.
set -euo pipefail

REGION="${1:-ap-south-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
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

# Refuse plain-HTTP access
POLICY_FILE="$(mktemp)"
cat > "${POLICY_FILE}" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"],
    "Condition": { "Bool": { "aws:SecureTransport": "false" } }
  }]
}
POLICY
aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "file://${POLICY_FILE}"
rm -f "${POLICY_FILE}"

# Keep old state versions for 90 days only (cost control)
LIFECYCLE_FILE="$(mktemp)"
cat > "${LIFECYCLE_FILE}" <<'LIFECYCLE'
{
  "Rules": [{
    "ID": "expire-old-state-versions",
    "Status": "Enabled",
    "Filter": {},
    "NoncurrentVersionExpiration": { "NoncurrentDays": 90 }
  }]
}
LIFECYCLE
aws s3api put-bucket-lifecycle-configuration --bucket "${BUCKET}" --lifecycle-configuration "file://${LIFECYCLE_FILE}"
rm -f "${LIFECYCLE_FILE}"

echo
echo "Done. Create infra/bootstrap/backend.hcl with:"
echo "  bucket       = \"${BUCKET}\""
echo "  key          = \"bootstrap/terraform.tfstate\""
echo "  region       = \"${REGION}\""
echo "  encrypt      = true"
echo "  use_lockfile = true"
