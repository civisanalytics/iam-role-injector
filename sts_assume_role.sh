#!/usr/bin/env bash

PURPLE="\033[35m"
WHITE="\033[0m"


arg_vars(){
    # Set aws args
    case "$1" in
        -d|--destination )
            DESTINATION_ACCOUNT="$2" ;;
        -m|--mfa )
            MFA_TOKEN="$2" ;;
        -r|--role )
            ROLE_NAME="$2" ;;
        -s|--source )
            AWS_ACCOUNT_NUMBER="$2" ;;
        -t|--timeout )
            timeout_time "$2" ;;
        -u|--user )
            AWS_USER="$2" ;;
    esac
}

assume_role(){
    header "AWS STS assume-role"
    roleArn="arn:aws:iam::"
    roleArn+="$DESTINATION_ACCOUNT"
    roleArn+=":role/"
    roleArn+="$ROLE_NAME"

    serialArn="arn:aws:iam::"
    serialArn+="$AWS_ACCOUNT_NUMBER"
    serialArn+=":mfa/"
    serialArn+="$AWS_USER"

    roleCommand="aws sts assume-role --role-arn $roleArn "
    roleCommand+="--role-session-name iam-role-injector "
    roleCommand+="--duration-seconds $TIMEOUT "
    roleCommand+="--serial-number $serialArn "
    roleCommand+="--query 'Credentials.[SecretAccessKey, SessionToken, AccessKeyId, Expiration]' "
    [ "$MFA_TOKEN" != NONE ] && \
        roleCommand+="--token-code $MFA_TOKEN"

    commandResult=$(eval "$roleCommand")
    exitCode=$?
    if [[ "$commandResult" && ${#commandResult} -gt 6 ]]; then
        arg1=$(echo "$commandResult" | awk -F\" 'NR==2 {print $2}')
        arg2=$(echo "$commandResult" | awk -F\" 'NR==3 {print $2}')
        arg3=$(echo "$commandResult" | awk -F\" 'NR==4 {print $2}')
        arg4=$(echo "$commandResult" | awk -F\" 'NR==5 {print $2}')
        # Set AWS_SESSION_TOKEN and AWS_SECURITY_TOKEN for backwards compatibility
        # See: http://boto3.readthedocs.org/en/latest/guide/configuration.html
        export AWS_SECRET_ACCESS_KEY="$arg1"
        export AWS_SECURITY_TOKEN="$arg2"
        export AWS_SESSION_TOKEN="$arg2"
        export AWS_ACCESS_KEY_ID="$arg3"
        export AWS_STS_EXPIRATION="$arg4"
        determine_timeout
        get_aws_account_name
        echo -e "$AWS_ACCOUNT_NAME:$ROLE_NAME\nexpiration: $AWS_STS_EXPIRATION UTC"
    else
        echo
        exitCode=1
        main -h
    fi
}

determine_timeout(){
    OS_TYPE=$(uname -s)
    # linux specific
    if [ "$OS_TYPE" = Linux ]; then
        export AWS_STS_TIMEOUT=$(date --date="$AWS_STS_EXPIRATION" "+%s")
    # mac specific
    elif [ "$OS_TYPE" = Darwin ]; then
        export AWS_STS_TIMEOUT=$(date -ujf "%Y-%m-%dT%H:%M:%SZ" "$AWS_STS_EXPIRATION" "+%s") # reassign var to epoch timestamp
    fi
}

exit_code(){
    (exit $exitCode)
}

get_aws_account_name(){
    AWS_ACCOUNT_NAME=$(aws iam list-account-aliases --query 'AccountAliases[]' --output text 2>&1)
    if grep -q 'error.*ListAccountAliases' <<< "$AWS_ACCOUNT_NAME"; then
        printf "$AWS_ACCOUNT_NAME\\n"
        exitCode=255
        exit_code
    else
        export AWS_ACCOUNT_NAME
    fi
}

get_aws_info(){
    if [ -z "$AWS_ACCOUNT_NUMBER" ] && [ -z "$AWS_USER" ]; then
        AWS_INFO=$(aws sts get-caller-identity --output text --query '[Account, Arn]' 2>&1)
        if grep -q 'error.*GetCallerIdentity'<<< "$AWS_INFO"; then
            printf "$AWS_INFO\\n"
            exitCode=255
            exit_code
        else
            AWS_ACCOUNT_NUMBER=$(awk '{print $1}' <<< "$AWS_INFO")
            AWS_USER=$(awk -F"/" '{print $2}' <<< "$AWS_INFO")
            if [ ! "$AWS_ACCESS_KEY_ID" ]; then
                AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
                AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
            fi
            get_aws_account_name
        fi
    fi
}

header(){
    echo -e "[${PURPLE}${1}${WHITE}]"
}

print_aws_info(){
    get_aws_info && \
    echo "$AWS_ACCOUNT_NUMBER $AWS_ACCOUNT_NAME/$AWS_USER $AWS_ACCESS_KEY_ID"
}

parse_args(){
    if [ $# -eq 0 ]; then
        prompt_args
    else
        TIMEOUT=3600
        MFA_TOKEN=NONE
        while [ $# -ne 0 ]; do
            arg_vars "$@"
            shift
        done
    fi
}

prompt_args(){
    # Prompt user if no args specified
    header "No values set, please enter at least the destination account number and role name to assume"
    printf "Source Account (Default is NONE): "
    read -r AWS_ACCOUNT_NUMBER
    printf "Destination Account: "
    read -r DESTINATION_ACCOUNT
    printf "IAM User Name (Default is NONE): "
    read -r AWS_USER
    printf "Role: "
    read -r ROLE_NAME
    printf "Timeout (Default is 1h): "
    read -r TIMEOUT
    printf "Multifactor Authentication? (default is NONE): "
    read -r MFA_TOKEN
    main -s "$AWS_ACCOUNT_NUMBER" -u "$AWS_USER" -d "$DESTINATION_ACCOUNT" -r "$ROLE_NAME" -t "$TIMEOUT" -m "$MFA_TOKEN"
}

print_help(){
    header "Help Menu Options"
    echo \
    "Specify at least a role (-r) and destination account (-d)
    -d|--destination    to which AWS account you will assume-role
    -h|--help           (this) help menu
    -i|--info           output aws Info
    -m|--mfa            multi-factor (2fa/mfa) authentication (default is NONE)
    -r|--role           aws role you wish be become
    -s|--source         source account id (not needed if you can 'aws iam list-account-aliases')
    -t|--timeout        duration in which assume-role will be functional
                        (values in (s)econds,(m)inutes,(h)ours - 60m up to 12h. Default is 3600s)
    -u|--user           iam user name (not needed if you can 'aws sts get-caller-identity')
    -x|--unset          unset assumed role vars"
}

rotate_keys(){
    unset AWS_SECURITY_TOKEN
    unset AWS_SESSION_TOKEN
    if [ "$AWS_ENV_VARS" != True ]; then
        if [ ! "$AWS_SECRET_ACCESS_KEY" ]; then
            export AWS_ENV_VARS="True"
        elif [ ! "$OG_AWS_SECRET_ACCESS_KEY" ]; then
            export OG_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
            export OG_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
        else
            export AWS_SECRET_ACCESS_KEY=$OG_AWS_SECRET_ACCESS_KEY
            export AWS_ACCESS_KEY_ID=$OG_AWS_ACCESS_KEY_ID
            unset AWS_ENV_VARS
        fi
    else
        unset AWS_SECRET_ACCESS_KEY
        unset AWS_ACCESS_KEY_ID
        unset AWS_USER
    fi
}

timeout_time(){
    if [ "$1" ]; then
        if [[ "$1" =~ [hH]$ ]]; then
            TIMEOUT="$(( ${1%?} * 60 * 60))"
        elif [[ "$1" =~ [mM]$ ]]; then
            TIMEOUT="$(( ${1%?} * 60))"
        elif [[ "$1" =~ [sS]$ ]]; then
            TIMEOUT="${1%?}"
        elif [[ "$1" =~ [0-9]$ ]]; then
            TIMEOUT="$1"
        fi
    else
        TIMEOUT=3600
    fi
}

unset_vars(){
    header "Reverting assume-role vars back to IAM user";
    unset AWS_INFO \
        AWS_ACCOUNT_NAME \
        AWS_ACCOUNT_NUMBER \
        AWS_SECURITY_TOKEN \
        AWS_SESSION_TOKEN \
        AWS_STS_EXPIRATION \
        AWS_USER \
        TIMEOUT
        print_aws_info
}

main(){
    case "$1" in
        -h|--help )
            print_help ;;
        -i|--info )
            header "Current AWS Info"
            print_aws_info ;;
        -x|--unset )
            rotate_keys
            unset_vars ;;
        "" )
            prompt_args ;;
        * )
            parse_args "$@" && \
            rotate_keys && \
            get_aws_info && \
            assume_role
            ;;
    esac
}

main "$@"
# This runs in a subshell, so it will not exit your shell when you are sourcing,
# but it still gives you the correct exit code if you read from $?
exit_code
