#!/usr/bin/env bash

PURPLE="\033[35m"
WHITE="\033[0m"


arg_vars(){
    # Set aws args
    case "$1" in
        -d|--destination )
            destinationaccount="$2" ;;
        -t|--timeout )
            timeout_time "$2" ;;
        -r|--role )
            rolename="$2" ;;
        -m|--mfa )
            mfatoken="$2" ;;
    esac
}

assume_role(){
    header "AWS STS assume-role"
    roleArn="arn:aws:iam::"
    roleArn+="$destinationaccount"
    roleArn+=":role/"
    roleArn+="$rolename"

    serialArn="arn:aws:iam::"
    serialArn+="$AWS_ACCOUNT_NUMBER"
    serialArn+=":mfa/"
    serialArn+="$AWS_USER"

    roleCommand="aws sts assume-role --role-arn $roleArn "
    roleCommand+="--role-session-name iam-role-injector "
    roleCommand+="--duration-seconds $AWS_STS_TIMEOUT "
    roleCommand+="--serial-number $serialArn "
    roleCommand+="--query 'Credentials.[SecretAccessKey, SessionToken, AccessKeyId, Expiration]' "
    [ "$mfatoken" != NONE ] && \
        roleCommand+="--token-code $mfatoken"

    commandResult=$(eval "$roleCommand")
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
        AWS_STS_TIMEOUT=$(date -ujf "%Y-%m-%dT%H:%M:%SZ" "$AWS_STS_EXPIRATION" "+%s") # reassign var to epoch timestamp
        export AWS_STS_TIMEOUT
        AWS_ACCOUNT_NAME=$(aws iam list-account-aliases --query 'AccountAliases[]' --output text)
        export AWS_ACCOUNT_NAME
        echo "$AWS_ACCOUNT_NAME:$rolename\nexpiration: $AWS_STS_EXPIRATION UTC"
    else
        echo
        main -h
    fi
}

get_aws_info(){
    AWS_ACCOUNT_NAME=$(aws iam list-account-aliases --query 'AccountAliases[]' --output text)
    AWS_INFO=$(aws sts get-caller-identity --output text --query '[Account, Arn]')
    AWS_ACCOUNT_NUMBER=$(awk '{print $1}' <<< "$AWS_INFO")
    AWS_USER=$(awk -F"/" '{print $2}' <<< "$AWS_INFO")
    [ "$AWS_ACCESS_KEY_ID" ] || \
        AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile default) \
        AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile default)
}

header(){
    echo -e "[${PURPLE}${1}${WHITE}]"
}

print_aws_info(){
    get_aws_info
    echo "$AWS_ACCOUNT_NUMBER $AWS_ACCOUNT_NAME/$AWS_USER: $AWS_ACCESS_KEY_ID"
}

parse_args(){
    if [ $# -eq 0 ]; then
        prompt_args
    else
        AWS_STS_TIMEOUT=3600
        mfatoken=NONE
        while [ $# -ne 0 ]; do
            arg_vars "$@"
            shift
        done
    fi
}

prompt_args(){
    # Prompt user if no args specified
    # read -rp "Source Account: " S
    printf "Destination Account: "
    read -r destinationaccount
    printf "Role: "
    read -r rolename
    printf "Timeout (Default: 1hr): "
    read -r timeout
    printf "Multifactor Authentication?: (default is NONE)"
    read -r mfa
    parse_args -d "$destinationaccount" -r "$rolename" -t "$timeout" -t "$mfa"
}

print_help(){
    header "Help Menu Options"
    echo \
    "Specify at least a role (-r) and destination account (-d)
    -d|--destination    to which AWS account you will assume-role
    -h|--help           (this) help menu
    -i|--info           output aws Info
    -m|--mfa            disable multi-factor (2fa/mfa) authentication (unspecified defaults to NONE)
    -r|--role           aws role you wish be become
    -t|--timeout        duration in which assume-role will be functional
                        (values in (s)econds,(m)inutes,(h)ours - 60m up to 12h. Default is 3600s)
    -u|--unset          unset assumed role vars"
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
        if [[ "$1" =~ h$\|H$ ]]; then
            AWS_STS_TIMEOUT="$(( ${1%?} * 60 * 60))"
        elif [[ "$1" =~ m$\|M$ ]]; then
            AWS_STS_TIMEOUT="$(( ${1%?} * 60))"
        elif [[ "$1" =~ s$\|S$ ]]; then
            AWS_STS_TIMEOUT="${1%?}"
        elif [[ "$1" =~ [0-9]$ ]]; then
            AWS_STS_TIMEOUT="$1"
        fi
    else
        AWS_STS_TIMEOUT=3600
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
        AWS_STS_TIMEOUT \
        AWS_USER
        print_aws_info
}

main(){
    case "$1" in
        -h|--help )
            print_help ;;
        -i|--info )
            header "Current AWS Info"
            print_aws_info ;;
        -u|--unset )
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
