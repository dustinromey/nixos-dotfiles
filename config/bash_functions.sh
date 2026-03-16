function mkcd() {
  mkdir -p "$@" && cd "$@"
}

function whatsmyip_pro () {
    # Find default interface
    IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    if [ -z "$IFACE" ]; then
        echo "Could not determine default network interface."
        return 1
    fi
    echo "Default Interface: $IFACE"

    # Internal IP Lookup
    INTERNAL_IP=$(ip addr show $IFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo "Internal IP: $INTERNAL_IP"

    # External IP Lookup
    EXTERNAL_IP=$(curl -s ifconfig.me)
    echo "External IP: $EXTERNAL_IP"
}

heic2png() {
	for f in "$@"; do
		magick "$f" "${f%.*}.png"
	done
}

extract() {
	for archive in "$@"; do
		if [ -f "$archive" ]; then
			case $archive in
			*.tar.bz2) tar xvjf $archive ;;
			*.tar.gz) tar xvzf $archive ;;
			*.bz2) bunzip2 $archive ;;
			*.rar) rar x $archive ;;
			*.gz) gunzip $archive ;;
			*.tar) tar xvf $archive ;;
			*.tbz2) tar xvjf $archive ;;
			*.tgz) tar xvzf $archive ;;
			*.zip) unzip $archive ;;
			*.Z) gzip -d $archive ;;
			*.7z) 7z x $archive ;;
			*) echo "don't know how to extract '$archive'..." ;;
			esac
		else
			echo "'$archive' is not a valid file!"
		fi
	done
}
