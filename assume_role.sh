# USAGE:
# requires 4 args and optionally a 5th, needs to be run with source to get exported variables to stick
# source assume_role.sh <sourceAccountNumber> <username> <destinationAccountNumber> <rolename> [durationSeconds]

sourceAccountNumber=$1
username=$2
destinationAccountNumber=$3
rolename=$4
durationSeconds=${5:-3600}
defaultShell=$(echo $SHELL)

roleArn="arn:aws:iam::${destinationAccountNumber}:role/${rolename}"
serialArn="arn:aws:iam::${sourceAccountNumber}:mfa/${username}"

clear_env_vars () {
    unset AWS_SECURITY_TOKEN
    unset AWS_SESSION_TOKEN
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
}

get_sts () {
  # allow a blank tokenCode for orgs that don't use an MFA
  echo "Enter MFA token code:"
  read tokenCode

  if [[ "$defaultShell" == *"zsh"* ]]; then
    export a="-A"
  else
    export a="-a"
  fi

  if [ -z "$tokenCode" ]; then
    read $a commandResult <<< $(aws sts assume-role --output text\
                  --role-arn $roleArn \
                  --role-session-name iam-role-injector \
                  --query 'Credentials.[SecretAccessKey, SessionToken, AccessKeyId]' \
                  --duration-seconds $durationSeconds)
  else
    read $a commandResult <<< $(aws sts assume-role --output text \
                  --role-arn $roleArn \
                  --role-session-name iam-role-injector \
                  --serial-number $serialArn \
                  --query 'Credentials.[SecretAccessKey, SessionToken, AccessKeyId]' \
                  --duration-seconds $durationSeconds \
                  --token-code $tokenCode)
  fi

  exitCode=$?
}

set_env_vars () {
  if (( ${#commandResult[@]} == 3 )); then
    echo "You have assumed the $rolename role successfully."
    export AWS_SECRET_ACCESS_KEY=${commandResult[0]}
    # Set AWS_SESSION_TOKEN and AWS_SECURITY_TOKEN for backwards compatibility
    # See: http://boto3.readthedocs.org/en/latest/guide/configuration.html
    export AWS_SECURITY_TOKEN=${commandResult[1]}
    export AWS_SESSION_TOKEN=${commandResult[1]}
    export AWS_ACCESS_KEY_ID=${commandResult[2]}
  else
    echo "Unable to assume role"
    exitCode=1
  fi
}

main () {
  if [ -n "$destinationAccountNumber" ] && [ -n "$sourceAccountNumber" ] && [ -n "$rolename" ] && [ -n "$username" ]; then
    clear_env_vars
    get_sts
    set_env_vars
  else
    echo "Usage: source assume_role.sh <sourceAccountNumber> <username> <destinationAccountNumber> <rolename> [durationSeconds]"
    exitCode=1
  fi

}

main
# This runs in a subshell, so it will not exit your shell when you are sourcing,
# but it still gives you the correct exit code if you read from $?
(exit $exitCode)
