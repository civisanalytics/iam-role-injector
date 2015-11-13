# USAGE:
# requires 4 args, needs to be run with source to get exported variables to stick
# source assume_role.sh {sourceAccountNumber} {username} {destinationAccountNumber} {rolename}

sourceAccountNumber=$1
username=$2
destinationAccountNumber=$3
rolename=$4

if [ -n "$destinationAccountNumber" ] && [ -n "$sourceAccountNumber" ] && [ -n "$rolename" ] && [ -n "$username" ]; then
  echo "Enter MFA token code:"
  read tokenCode
  unset AWS_SECURITY_TOKEN
  if [ -z "$AWS_ENV_VARS" ]; then
    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
      export AWS_ENV_VARS="True"
    elif [ -z "$OG_AWS_SECRET_ACCESS_KEY" ]; then
      export OG_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
      export OG_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    else
      export AWS_SECRET_ACCESS_KEY=$OG_AWS_SECRET_ACCESS_KEY
      export AWS_ACCESS_KEY_ID=$OG_AWS_ACCESS_KEY_ID
    fi
  else
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_ACCESS_KEY_ID
  fi

  roleArn="arn:aws:iam::"
  roleArn+="$destinationAccountNumber"
  roleArn+=":role/"
  roleArn+="$rolename"

  serialArn="arn:aws:iam::"
  serialArn+="$sourceAccountNumber"
  serialArn+=":mfa/"
  serialArn+="$username"

  commandResult=" "
  commandResult+=$(aws sts assume-role --role-arn $roleArn \
                  --role-session-name iam-role-injector \
                  --serial-number $serialArn \
                  --query 'Credentials.[SecretAccessKey, SessionToken, AccessKeyId]' \
                  --token-code $tokenCode)

  size=${#commandResult}
  if (( $size > 5 )); then
    commandResult1=$(echo "$commandResult" | sed '5d' | sed '1d' | tr -d '\040\011\012\015' | sed 's/\"//g')
    echo "You have assumed the $rolename role successfully."
    arg1=$(echo "$commandResult1" | cut -d "," -f1)
    export AWS_SECRET_ACCESS_KEY=$arg1
    arg2=$(echo "$commandResult1" | cut -d "," -f2)
    export AWS_SECURITY_TOKEN=$arg2
    arg3=$(echo "$commandResult1" | cut -d "," -f3)
    export AWS_ACCESS_KEY_ID=$arg3
  fi

else
  echo "Usage: source assume_role.sh {sourceAccountNumber} {username} {destinationAccountNumber} {rolename}"
fi
