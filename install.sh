#!/bin/bash

install_tools(){

    command_output=$(command -v ifconfig)
    if [ -z "$command_output" ]; then
        echo "ifconfig not found... installing net-tools"
        apt install -y net-tools 
    else
        echo "ifconfig already found..."
    fi 

    adb_output=$(command -v adb)
    if [ -z "$adb_output" ]; then
        echo "adb not found... installing adb"
        apt install -y adb 
    else
        echo "adb already found..."
    fi

    ifmetric_output=$(command -v ifmetric)
    if [ -z "$ifmetric_output" ]; then
        echo "ifmetric not found... installing ifmetric"
        apt install -y ifmetric 
    else
        echo "ifmetric already found..."
    fi
}

install(){
    echo "installation will begin"
    install_tools
    echo ""
    lsusb
    echo ""
    echo "vendorId and productId of android device from above usb list"
    echo "enter usb vendor id"
    read vendor_id
    echo "enter usb product id"
    read product_id

    rules_file='/etc/udev/rules.d/android-rndis-tethering.rules'
    service_file='/etc/systemd/system/android-rndis-tethering.service'

    echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$vendor_id\", ATTR{idProduct}==\"$product_id\", MODE=\"0666\", GROUP=\"plugdev\"" > $rules_file
    echo "SUBSYSTEM==\"net\", ENV{ID_BUS}==\"usb\", ENV{ID_USB_DRIVER}==\"rndis_host\", ACTION==\"add\",NAME=\"android_rndis\", RUN{program}+=\"/bin/sh -c 'echo $env{INTERFACE} > /var/tmp/myfile'\"" >> $rules_file

    mkdir /etc/android-rndis-tethering 

    script_file='/etc/android-rndis-tethering/rndis.sh'

    echo "#!/bin/bash" > $script_file
    echo "" >> $script_file
    echo "check_and_proceed() {
    ip=\"192.168.234.150\"
    gateway=\"192.168.234.129\"
    devices=\$(adb devices | awk 'NR>1 {print $1}')
    if [ -z \"\$devices\" ]; then
        echo \"No devices found.\"
    else
        for device in \$devices; do
            if [[ \"\$device\" == \"device\" ]]; then
                echo
            else 
                echo \"device \$device\"
                current_mode=\$(adb -s \$device shell svc usb getFunctions 2>&1)
                echo Current Mode: \$current_mode
                if [[ \"\$current_mode\" == \"rndis\" ]]; then
                    echo Already in rndis Mode. Checking IP
                    if check_ip_address \"\$ip\"; then
                        echo \"Device already has an IP address\"
                    else
                        echo \"Need to set IP. Proceeding...\"
                        set_ip_address \"\$ip\" \"\$gateway\"
                    fi
                else
                    echo Not in rndis Mode. Proceeding to enable rndis mode
                    set_usb_mode \"\$device\"
                    echo Enabled rndis Mode.
                fi
            fi
        done
    fi
}" >> $script_file

    echo "" >> $script_file

    echo "set_usb_mode() {
    # Set the USB mode to RNDIS
    adb -s \"\$1\" shell svc wifi disable
    adb -s \"\$1\" shell svc usb setFunctions rndis
}" >> $script_file

    echo "" >> $script_file

    echo "check_ip_address() {
    ip=\"\$1\"
    # Check if the device has an IP address
    adb_output=\$(ip -f inet addr show android_rndis 2>/dev/null)
    if [[ \"\$adb_output\" == *\"\$ip\"* ]]; then
        return 0
    else
        return 1
    fi
}" >> $script_file

    echo "" >> $script_file

    echo "set_ip_address() {
    ip=\"\$1\"
    gateway=\"\$2\"
    # Set the IP address and gateway
    ip addr flush android_rndis
    ip addr add \"\$ip/24\" dev android_rndis
    ip route add \"\$ip/24\" dev android_rndis
    ip route add \"\$ip/24\" via \"\$gateway\"
    ip route add default via \"\$gateway\" dev android_rndis
    ip link set android_rndis up
    #iptables -t nat -A PREROUTING -d \"\$ip\" -j DNAT --to-destination 192.168.5.100
    #iptables -t nat -A POSTROUTING -s 192.168.5.100 -j SNAT --to-destination \"\$ip\"
    ifmetric android_rndis 1000000
}" >> $script_file

    echo "" >> $script_file

    echo "create_virtual_interface(){
    modprobe dummy
    ip link add eth-v type dummy
    ifconfig eth-v hw ether C8:D7:4A:4E:47:50
    ip addr add 192.168.234.100/24 brd + dev eth-v
    ip link set dev eth-v up
    ifmetric eth-v 7500000
}" >> $script_file

    echo "" >> $script_file

    echo "create_virtual_interface" >> $script_file

    echo "" >> $script_file

    echo "while true; do
    check_and_proceed
    sleep 5
done" >> $script_file

    chmod +x $script_file

    echo "[Unit]
 Description=Tethering Service
 After=network-online.target
 Wants=network-online.target systemd-networkd-wait-online.service

[Service]
 Type=simple
 User=root
 ExecStart=/bin/bash $script_file
 Group=root
 Restart=always
 RestartSec=5s

[Install]
 WantedBy=multi-user.target" > $service_file

    systemctl enable android-rndis-tethering.service 
    systemctl start android-rndis-tethering.service 

    echo "installation done. now reboot the system"
}



uninstall(){
  echo "android tethering will be uninstalled"
  systemctl stop android-rndis-tethering.service
  systemctl disable android-rndis-tethering.service 
  rm /etc/systemd/system/android-rndis-tethering.service
  rm /etc/udev/rules.d/android-rndis-tethering.rules
  rm /etc/android-rndis-tethering/rndis.sh
  echo "android tethering uninstalled."
}

option="${1}" 
case ${option} in 
   -i) install
      ;; 
   -u) uninstall
      ;; 
   *)  
      echo "Unknown flag. use i for install and u for un-install" 
      exit 1 # Command to come out of the program with status 1
      ;; 
esac 