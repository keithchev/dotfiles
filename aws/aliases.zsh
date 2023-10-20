
alias s3ls='aws s3 ls --human-readable'

function s3up () {
    aws s3 cp $1 s3://$2
}

function s3down () {
    aws s3 cp s3://$1 $2
}

function s3rm () {
    aws s3 rm --dryrun s3://$1
}

function s3rm-im-sure () {
    aws s3 rm s3://$1
}

# list all ec2 instances as rows of (id, state, name)
alias ec2ls='aws ec2 describe-instances | \
    jq -r ".Reservations[].Instances[] | \
    (.InstanceId + \" \" + .State.Name + \" \" + ( .Tags[]? | select(.Key == \"Name\") | .Value))"'

function ec2status () {
    aws ec2 describe-instance-status --instance-id $1
}
