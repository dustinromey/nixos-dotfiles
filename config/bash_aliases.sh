
# To temporarily bypass an alias, we precede the command with a \
# EG: the ls command is aliased, but to use the normal ls command you would type \ls#

# shows used diskspace
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias cat='bat --paging=never'

# Alias's to modified commands
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias ls="ls -lah "
alias whatismyip="whatsmyip_pro"
alias zed='zeditor'
alias nrs='sudo nixos-rebuild switch --flake ~/nixos-dotfiles#$(hostname)'

# Romey Inc DBs
alias dbromey='pgcli -h romeyinc.net -U admin romey'
alias dbupgrade='pgcli -h romeyinc.net -U admin upgrade'

# Tony BTW Tutorial
alias btw="echo I use nixos, btw"

alias gemini="npx @google/gemini-cli"
