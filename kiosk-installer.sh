#!/bin/bash

function usage() {
	cat << HEREDOC
Usage: $progname <-p PASS> <-u URL> [-r X,Y] [-z ZT_NET_ID] [-h RD_HOST] [-k RD_KEY] [-a]

  required arguments:
    -p    password for SSH kiosk user and RustDesk
    -u    url to open in browser

  optional arguments:
    -r    resolution X,Y (default: 1024,768)
    -z    ZeroTier Network ID, if you want to join ZT network
    -h    RustDesk self-hosted server hostname
    -k    RustDesk self-hosted server key
    -a    Ask for [enter] key on each step

HEREDOC
}

# init vars (you can setup defaults here)
progname=$(basename $0)
res="1024,768"
passwd=
ztn=
rdh=
rdk=
url=
pause=0

rustdesk_ver="1.1.9"


OPTS=$(getopt -o "p:r:z:h:k:a" -n "$progname" -- "$@")
if [ $? != 0 ]; then echo "Error. Bad arguments." >&2; usage; exit 1; fi
eval set -- "$OPTS"

while true; do
	case "$1" in
		-p ) passwd="$2"; shift 2 ;;
		-p ) url="$2"; shift 2 ;;
		-r ) res="$2"; shift 2 ;;
		-z ) ztn="$2"; shift 2 ;;
		-h ) rdh="$2"; shift 2 ;;
		-k ) rdk="$2"; shift 2 ;;
		-a ) pause=1; shift ;;
		-- ) shift; break ;;
		* ) break ;;
	esac
done


if [ -z "$passwd" ]; then usage; exit 1; fi
if [ -z "$url" ]; then usage; exit 1; fi


echo "configuring for:"
echo "  password      = $passwd"
echo "  url           = $url"
echo "  resolution    = $res"
echo "  zerotier net  = $ztn"
echo "  rustdesk host = $rdh"
echo "  rustdesk key  = $rdk"
echo
echo "press [enter] to continue."
read



echo "--- Updating system and installing packages"
[ $pause -gt 0 ] && echo "[enter]" && read

apt-get update
apt-get install \
	unclutter \
	xorg \
	chromium \
	openbox \
	lightdm \
	locales \
	sudo \
	libxdo3 \
	pulseaudio \
	python3-pip \
	curl \
	-y

echo "--- Add kiosk user and setup autologin"
[ $pause -gt 0 ] && echo "[enter]" && read

echo "--- Add kiosk user"
useradd -m -U -s /bin/bash kiosk
echo "kiosk:$passwd" | chpasswd
usermod -a -G sudo kiosk
echo '%sudo ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopass

echo "--- Setup autologin"
sed -i 's/^\[Seat:\*]$/\[Seat:\*]\nautologin-user=kiosk/' /etc/lightdm/lightdm.conf
mkdir -p /home/kiosk/.config/openbox

cat > /home/kiosk/.config/openbox/autostart << EOF
#!/bin/bash

#unclutter -idle 0.1 -grab -root &
rustdesk &

while :
do
  chromium \\
    --no-first-run \\
    --start-maximized \\
    --window-position=0,0 \\
    --window-size=$res \\
    --disable \\
    --disable-translate \\
    --disable-infobars \\
    --disable-suggestions-service \\
    --disable-session-crashed-bubble \\
    --kiosk "$url"
  sleep 5
done &
EOF

echo "--- Enable and Start SSH"
systemctl enable ssh
systemctl start ssh


echo "--- Install ZeroTier"
[ $pause -gt 0 ] && echo "[enter]" && read

curl -s https://install.zerotier.com | bash
if [ -n "$ztn" ]; then
	echo "--- Join ZeroTier Network"
	zerotier-cli join $ztn
fi



echo "--- Install RustDesk"
[ $pause -gt 0 ] && echo "[enter]" && read

wget "https://github.com/rustdesk/rustdesk/releases/download/$rustdesk_ver/rustdesk-$rustdesk_ver.deb"
mkdir -p /home/kiosk/.config/rustdesk
mkdir -p /root/.config/rustdesk

if [ -n "$rdh" ]; then
	cat > /home/kiosk/.config/rustdesk/RustDesk2.toml << EOF
rendezvous_server = 'rs-ny.rustdesk.com'
nat_type = 1
serial = 3

[options]
rendezvous-servers = 'rs-ny.rustdesk.com,rs-sg.rustdesk.com,rs-cn.rustdesk.com'
key = '$rdk'
custom-rendezvous-server = '$rdh'
relay-server = '$rdh'
EOF
	cat > /root/.config/rustdesk/RustDesk2.toml << EOF
rendezvous_server = 'rs-ny.rustdesk.com'
nat_type = 1
serial = 3

[options]
rendezvous-servers = 'rs-ny.rustdesk.com,rs-sg.rustdesk.com,rs-cn.rustdesk.com'
key = '$rdk'
custom-rendezvous-server = '$rdh'
relay-server = '$rdh'
EOF
fi
echo "password = '$passwd'" >> /root/.config/rustdesk/RustDesk.toml
echo "password = '$passwd'" >> /home/kiosk/.config/rustdesk/RustDesk.toml

dpkg -i rustdesk-$rustdesk_ver.deb


echo "--- Setup .bashrc for kiosk and root users"

# bashrc
echo 'echo -e "\n\nRustDesk "' >> /root/.bashrc
echo 'grep id /home/kiosk/.config/rustdesk/RustDesk.toml' >> /root/.bashrc
echo 'grep password /home/kiosk/.config/rustdesk/RustDesk.toml' >> /root/.bashrc
echo 'echo -e "\n\nRustDesk: "' >> /home/kiosk/.bashrc
echo 'grep id /home/kiosk/.config/rustdesk/RustDesk.toml' >> /home/kiosk/.bashrc
echo 'grep password /home/kiosk/.config/rustdesk/RustDesk.toml' >> /home/kiosk/.bashrc

chown -R kiosk:kiosk /home/kiosk

echo "--- Done! You can reboot now!"

