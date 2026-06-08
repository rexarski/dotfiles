# Environment Variables
# --------------------

zoxide init fish | source

# Aliases
# -------
# Python related
alias pip=pip3
alias python=python3

# File listing (eza)
if type -q eza
    alias ll "eza -l -g --icons"
    alias lla "ll -a"
end

# uv
fish_add_path "/Users/rexarski/.local/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Obsidian CLI
fish_add_path /Applications/Obsidian.app/Contents/MacOS

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Emacs aliases
function em
    emacs -nw $argv
end

function emacsgui
    emacs $argv
end

# yazi

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end
# peon-ping quick controls
function peon; bash /Users/rexarski/.claude/hooks/peon-ping/peon.sh $argv; end

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/rexarski/.lmstudio/bin
# End of LM Studio CLI section

