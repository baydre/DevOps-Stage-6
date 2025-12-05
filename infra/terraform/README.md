# Terraform Drift Detection System

This document describes the Terraform drift detection system implemented for this infrastructure. The drift detection system monitors your infrastructure for changes made outside of Terraform and notifies you when such changes are detected.

## Overview

The drift detection system consists of the following components:

1. **Remote Backend** (`backend.tf`): Configures S3 as the remote backend for storing Terraform state with DynamoDB for state locking.
2. **Drift Detection Logic** (`drift_detection.tf`): Implements AWS Lambda-based drift detection with SNS notifications.
3. **Notification Script** (`scripts/drift-notification.sh`): Sends email notifications when drift is detected.
4. **CI/CD Integration**: The system integrates with CI/CD pipelines to pause and wait for manual approval when drift is detected.

## How Drift Detection Works

The drift detection system works as follows:

1. **Scheduled Checks**: A CloudWatch Event triggers the drift detection Lambda function on a scheduled basis (default: every 24 hours).
2. **State Comparison**: The Lambda function downloads the current Terraform state from S3 and runs `terraform plan` to detect any drift.
3. **Drift Detection**: If `terraform plan` returns an exit code of 2, it indicates that drift has been detected.
4. **Notification**: When drift is detected, the system sends an email notification with details about the detected drift.
5. **Manual Approval**: The CI/CD pipeline pauses and waits for manual approval before applying any changes.
6. **Action Required**: The recipient must approve or reject the changes using the links provided in the email.

## Configuration

### Remote Backend

The remote backend is configured in [`backend.tf`](backend.tf:1) with the following settings:

- **S3 Bucket**: `hng-devops-tf-state` - Stores the Terraform state file
- **DynamoDB Table**: `terraform-state-lock` - Provides state locking
- **Encryption**: Server-side encryption is enabled for the state file
- **Versioning**: State file versioning is enabled to maintain history

### Drift Detection

The drift detection logic is implemented in [`drift_detection.tf`](drift_detection.tf:1) with the following components:

- **SNS Topic**: `hng-devops-drift-notifications` - Used for sending notifications
- **Lambda Function**: `hng-devops-drift-detection` - Performs the drift detection
- **CloudWatch Event Rule**: `hng-devops-drift-detection-schedule` - Triggers the Lambda function
- **IAM Role and Policy**: Provides necessary permissions for the Lambda function

### Notification Script

The notification script [`scripts/drift-notification.sh`](scripts/drift-notification.sh:1) sends email notifications when drift is detected. It supports multiple email sending methods:

1. **sendmail**: Uses the local sendmail command
2. **mail**: Uses the mail command
3. **AWS SES**: Uses AWS Simple Email Service (requires AWS CLI)

## CI/CD Integration

The drift detection system integrates with CI/CD pipelines as follows:

1. **Drift Detection**: The pipeline runs `terraform plan` to detect drift.
2. **Notification**: If drift is detected, the notification script is called with the plan output.
3. **Pause**: The pipeline pauses and waits for manual approval.
4. **Approval**: The user approves or rejects the changes using the links in the email.
5. **Continue**: If approved, the pipeline continues with `terraform apply`. If rejected, the pipeline stops.

## Manual Approval Process

When drift is detected, the following process is followed:

1. **Email Notification**: An email is sent to the configured address with details about the detected drift.
2. **Review Changes**: The recipient reviews the changes described in the email.
3. **Take Action**: The recipient clicks on the approval or rejection link in the email.
4. **Pipeline Continuation**: The CI/CD pipeline continues based on the action taken.

## Troubleshooting

### Common Issues

1. **No Email Received**
   - Check the spam/junk folder
   - Verify the email address is correct in [`drift_detection.tf`](drift_detection.tf:258)
   - Ensure the SNS topic is properly configured

2. **Lambda Function Fails**
   - Check CloudWatch Logs for error messages
   - Verify the Lambda function has the necessary permissions
   - Ensure the S3 bucket and DynamoDB table exist

3. **State Locking Issues**
   - Ensure the DynamoDB table exists and is properly configured
   - Check for any stuck state locks and manually release if necessary

4. **CI/CD Pipeline Issues**
   - Verify the pipeline is configured to run `terraform plan` with the `-detailed-exitcode` flag
   - Ensure the notification script is executable and has the correct permissions

### Debugging Steps

1. **Check CloudWatch Logs**
   - Navigate to the CloudWatch console
   - Find the log group for the Lambda function
   - Review the logs for error messages

2. **Test the Lambda Function**
   - Use the AWS Lambda console to test the function with a test event
   - Verify the function is able to download the state file and run `terraform plan`

3. **Verify SNS Configuration**
   - Check the SNS topic exists and has the correct subscriptions
   - Verify the email address is confirmed in AWS SES

4. **Check Backend Configuration**
   - Verify the S3 bucket and DynamoDB table exist
   - Ensure the Terraform backend is properly configured

## Customization

### Changing the Check Frequency

To change how often drift detection is run, modify the `schedule_expression` in the CloudWatch Event rule:

```hcl
schedule_expression = "rate(24 hours)"  # Change this value as needed
```

### Adding Additional Notification Methods

To add additional notification methods, modify the Lambda function in [`drift_detection.tf`](drift_detection.tf:26) to include the desired notification logic.

### Customizing Email Content

To customize the email content, modify the message template in the Lambda function or the [`scripts/drift-notification.sh`](scripts/drift-notification.sh:1) script.

## Security Considerations

1. **State File Security**: The Terraform state file is encrypted at rest in S3.
2. **Access Control**: IAM roles and policies restrict access to the state file and drift detection resources.
3. **Notification Security**: Email notifications are sent through secure channels.
4. **Approval Security**: Approval links should be secured with authentication and authorization.

## Conclusion

The Terraform drift detection system provides a robust mechanism for monitoring infrastructure changes and ensuring that all modifications are properly reviewed and approved. By integrating with CI/CD pipelines and providing clear notification and approval processes, the system helps maintain infrastructure integrity and prevent unauthorized changes.