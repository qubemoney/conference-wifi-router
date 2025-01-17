# Qube Router Configuration

This repo is used to configure routers similar to [this one](https://www.amazon.com/dp/B09N72FMH5?ref=ppx_yo2ov_dt_b_fed_asin_title) for use at conferences.

## HOW TO SETUP

1. Fetch the [admin password for the Router here](https://start.1password.com/open/i?a=YSMHNCAEVNFZTOOBO6BKFKX63U&v=by76lmejjnc4vdasehbe4zqlf4&i=6bxh3ernj5dnrf6cfdzu76nqea&h=qubemoney.1password.com)
2. Fetch the [Qube Employee Wifi password here](https://start.1password.com/open/i?a=YSMHNCAEVNFZTOOBO6BKFKX63U&v=ynsgmvelvhk5wq7nkfhvkyqcbm&i=ytowydxkivcbxllbpb5zd7xksm&h=qubemoney.1password.com)
3. Follow [this instructional video](https://vimeo.com/1046890150) on first configuring the router. Please note that all wifi networks across different reouters should be unique. It can cause problems if there are two "Qube Employee" networks next to eachother
4. Next, open terminal on Mac, or Command Pallete on Windows
5. run this command to SSH into your router:
```
ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.8.1
```
6. Enter the [admin password for the Router](https://start.1password.com/open/i?a=YSMHNCAEVNFZTOOBO6BKFKX63U&v=by76lmejjnc4vdasehbe4zqlf4&i=6bxh3ernj5dnrf6cfdzu76nqea&h=qubemoney.1password.com)
7. You should now see the following:
```
BusyBox v1.29.3 () built-in shell (ash)

  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 18.06, LEDE
 -----------------------------------------------------
root@GL-SFT1200:~#
```
8. run:
```
curl -O https://raw.githubusercontent.com/qubemoney/conference-wifi-router/main/main.sh -o "/usr/bin/qube_reboot.sh" && chmod +x /usr/bin/qube_reboot.sh && sh /usr/bin/qube_reboot.sh
```
