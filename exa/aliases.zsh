# standard ls
alias ll="exa -al --sort=name --time-style=long-iso --group-directories-first"

# only directories
alias lld="ll -d */"

# sort by file size (largest last)
alias lls="exa -al --sort=size --time-style=long-iso"

# sort by last modified (most recent last)
alias llt="exa -al --sort=modified --time-style=long-iso"

# only directories, sort by last modified
alias lltd="llt -d */"
alias lldt="lltd"

# show tree view of current directory (sub-directories and their contents)
alias lltree="exa -al --sort=name --tree --level=2"

# show tree view of with an extra level (sub-sub-directories and their contents)
alias lltree3="exa -al --sort=name --tree --level=3"

# list only files of a certain type
llf () {
    ll | grep --color=always "\.$1$"  
}
