# iam-role-injector

The IAM Role Injector is a tool for easily assuming an IAM Role with
Multi-Factor Authentication (MFA). It manipulates environment variables
to allow codebases already using AWS credentials to use IAM roles with minimal to no
refactoring. In the same vein, the Role Injector can also be used to help users using the
command line tools to assume a role.

## Assumptions
 - AWS CLI configured correctly, storing 'aws_access_key_id' and
   'aws_secret_access_key' in either environment variables -OR- in
   ~/.aws/credentials
 - One of the following Scenarios apply:
### Scenario One: Federated AWS Accounts
 - At least two AWS Accounts:
   - AWS Account 1 must have a policy that includes sts:AssumeRole to AWS Account 2
   - AWS Account 2 must have a Trust Relationship on a role that references AWS Account 1
 - AWS Account 1 may now assume the the role in AWS Account 2 that has the Trust Relationship

### Scenario Two: Single AWS Account:
 - An IAM User Account with a policy that include sts:Assume on a IAM
   Role.
 - The IAM Role has a policy that allows the IAM User to assume it
 - In this case, AWS Account 1 and AWS Account 2 are the same.

## Installation

1. [Install aws cli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
2. Configure AWS CLI with required credentials, either as Environment
   Variables or through 'aws configure'
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


