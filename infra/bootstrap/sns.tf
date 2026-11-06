resource "aws_sns_topic" "ci" {
  name              = "${var.project}-ci-notifications"
  kms_master_key_id = "alias/aws/sns"
}

# The subscription stays "Pending confirmation" until you click the link in the email AWS sends
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ci.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
