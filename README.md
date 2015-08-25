# iam-role-injector

The IAM Role Injector is a tool for easily assuming an IAM Role with
Multi-Factor Authentication (MFA). It manipulates environment variables
to allow codebases already using AWS credentials to use IAM roles with minimal to no
refactoring. In the same vein, the Role Injector can also be used to help users using the
command line tools to assume a role.

## Assumptions

 - At least two AWS Accounts:
   - AWS Account 1 must have a policy that includes sts:AssumeRole to AWS Account 2
   - AWS Account 2 must have a Trust Relationship on a role that references AWS Account 1
 - AWS Account 1 may now assume the the role in AWS Account 2 that has the Trust Relationship

## Installation

1. [Install aws cli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
2. Run `aws configure` and specify the credentials for AWS Account 1
3. `wget -N https://raw.githubusercontent.com/civisanalytics/iam-role-injector/master/assume_role.sh -O ~/assume_role.sh`

## Command Line Usage

```
source ~/assume_role.sh {destinationAccountNumber} {sourceAccountNumber} {rolename} {username}
```

 - `destinationAccountNumber`: AWS Account Number of AWS Account 2
 - `sourceAccountNumber`: AWS Account Number of AWS Account 1
 - `rolename`: the name of the role to assume in AWS Account 2 that has the Trust Relationship to AWS Account 1
 - `username`: AWS Account 1 username

Calling the script with 'source' is required for the
environment variables to persist past the runtime of the script.

The script will also protect your original credentials if you chose to
store *them* as environment variables.

## Bugs

Please report any bugs to:
https://github.com/civisanalytics/iam-role-injector/issues

## Contributing

Open an issue or a pull request if you see how we can improve the
script!


