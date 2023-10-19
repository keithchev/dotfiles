
alias s3ls='aws s3 ls'
alias s3ls='aws s3 ls s3://$1'

alias s3cp='aws s3 cp $1 s3://$2'
alias s3rm='aws s3 rm --dryrun s3://$1'
alias s3rm-im-sure='aws s3 rm s3://$1'

alias ec2ls='aws ec2 describe-instances | \
    jq -r ".Reservations[].Instances[] | \
    (.InstanceId + \" \" + .State.Name + \" \" + ( .Tags[]? | select(.Key == \"Name\") | .Value))"'

alias ec2status='aws ec2 describe-instance-status --instance-id $1'
