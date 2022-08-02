# Forked version
This is forked and modified version of the kiosk-installer.
I've modified the script to my needs and dded some arguments to it.
I've also added [ZeroTier](https://zerotier.com) and [RustDesk](https://rustdesk.com) to the installation.

## Usage
* Setup a minimal Debian without display manager, e.g. Debian netboot cd
* Login as root or with root permissions
* Download this installer, make it executable and run it

  `wget https://raw.github.com/0xAF/debian-kiosk-installer/master/kiosk-installer.sh; chmod +x kiosk-installer.sh; ./kiosk-installer.sh`

If you are installing to a Raspberry Pi, change chromium to chromium-browser in the install script (both in apt line and startup command)

## What will it do?
It will create a normal user `kiosk`, install software (check the script) and setup configs so that on reboot the kiosk user will login automaticaly and run chromium in kiosk mode with one url.

## Is it secure?
No. Although it will run as a normal user (and I suggest you don't leave a keyboard and mouse hanging around), there will be the possibility of plugin' in a mini keyboard, opening a terminal and opening some nasty things. Security is your thing ;-) 

