
function s3-ls () {
    local dir=$1
    # append a trailing slash.
    [[ "${dir}" != */ ]] && dir="${dir}/"
    aws s3 ls --human-readable "${dir}"
}


function s3-size-gb () {
    local dir=$1
    # append a trailing slash.
    [[ "${dir}" != */ ]] && dir="${dir}/"
    aws s3 ls --recursive "${dir}" | \
        awk '{size += $3} END {print "Total size: " size/1024/1024/1024 " GB"}'
}

function s3-up () {
    aws s3 cp $1 s3://$2
}

function s3-down () {
    aws s3 cp s3://$1 $2
}

function s3-rm () {
    aws s3 rm --dryrun s3://$1
}

function s3-rm-im-sure () {
    aws s3 rm s3://$1
}

# list all ec2 instances as rows of (id, state, name)
alias ec2-ls='aws ec2 describe-instances | \
    jq -r ".Reservations[].Instances[] | \
    (.InstanceId + \" \" + .State.Name + \" \" + ( .Tags[]? | select(.Key == \"Name\") | .Value))"'

function ec2-status () {
    aws ec2 describe-instance-status --instance-id $1
}
