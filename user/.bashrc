_isroot=false
[[ $UID -eq 0 ]] && _isroot=true

export TERM='xterm-256color'
	B='\[\e[1;38;5;33m\]'
	LB='\[\e[1;38;5;81m\]'
	GY='\[\e[1;38;5;242m\]'
	G='\[\e[1;38;5;82m\]'
	P='\[\e[1;38;5;161m\]'
	PP='\[\e[1;38;5;93m\]'
	R='\[\e[1;38;5;196m\]'
	Y='\[\e[1;38;5;214m\]'
	W='\[\e[0m\]'

get_prompt_symbol() {
	[[ $UID == 0 ]] && echo "#" || echo "\$"
}

export PS1="$GY[$Y\u$GY@$P\h$GY:$B\w$GY]$W\$(get_prompt_symbol) "

export TERM='xterm-256color'

## COMPLETION
complete -cf sudo
if [[ -f /etc/bash_completion ]]; then
	. /etc/bash_completion
fi

## EXPORTS
if [[ -d "$HOME/bin" ]] ; then
	PATH="$HOME/bin:$PATH"
fi

export EDITOR="nano"

## BASH HISTORY
# make multiple shells share the same history file
export HISTSIZE=9000000            # bash history will save N commands
export HISTFILESIZE=${HISTSIZE} # bash will remember N commands
export HISTCONTROL=ignoreboth   # ignore duplicates and spaces
export HISTIGNORE='&:ls:ll:la:cd:exit:clear:history'

# AUTOCOLOR
alias ls='ls -lh --color=auto'
alias ll='ls'
alias la='ll -A'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# MODIFIED COMMANDS
alias ..='cd ..'
alias df='df -h'
alias diff='colordiff'              # requires colordiff package
alias du='du -c -h'
alias free='free -m'                # show sizes in MB
alias grep='grep --color=auto'
alias grep='grep --color=tty -d skip'
alias mkdir='mkdir -p -v'
alias more='less'
alias nano='nano -WciSH$'
alias ping='ping -c 5'

# ENTER AND LIST DIRECTORY
function cd() { builtin cd -- "$@" && { [ "$PS1" = "" ] || ls -hrt --color; }; }

# SYSTEMD SUPPORT
if which systemctl &>/dev/null; then
start() {
	sudo systemctl start $1.service
}
restart() {
	sudo systemctl restart $1.service
}
stop() {
	sudo systemctl stop $1.service
}
enable() {
	sudo systemctl enable $1.service
}
status() {
	sudo systemctl status $1.service
}
disable() {
	sudo systemctl disable $1.service
}
fi
