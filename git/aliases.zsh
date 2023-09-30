alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'

alias gs='git status -sb'
alias gt='git status'
alias gb="git branch -a -vv"
alias gr="git remote -vv"

alias glg='git log --pretty=format:"%h %Cblue %d %Cred %ad %Cgreen %ae %Creset %<(100,trunc) %s" --date=short --graph --all'

# Remove `+` and `-` from start of diff lines; just rely upon color.
alias gd='git diff --color | sed "s/^\([^-+ ]*\)[-+ ]/\\1/" | less -r'

# change both the author date and commit date of the most recent commit
function git-commit-amend-date() {
    new_date=$1
    GIT_COMMITTER_DATE="$new_date" GIT_AUTHOR_DATE="$new_date" git commit --amend --no-edit --date "$new_date"
}
