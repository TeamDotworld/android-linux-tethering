**Android and Linux Tethering**

# **Installation steps :**

1.  Download ```install.sh```

2.  Give permission for downloaded file using ```chmod +x install.sh```

3.  Plug the Android Alcatel tab using USB Cable and make sure linux is connected to the internet.

4.  Run ```sudo ./install.sh -i```.

5.  The script will request the vendorId and productId of the Android USB connection. You can find it in the script log or by entering the lsusb command in a different terminal tab.

6.  After entering the vendorId and productId, the script will begin installation.

7.  The script will install all necessary files and permissions itself.

8.  After completion of the installation, reboot Linux.

# **Working Algorithm :**

1.  Creates a virtual interface in a Linux system named ```eth-v``` and sets ```192.168.42.100``` as static ipv4, it will also act as master IP.

2.  The tethering service will run every 5 seconds and check if there is any ADB device connected to Linux.

3.  If any ADB device is found, the service will update the Android device in RNDIS mode. If it is already in RNDIS mode, no action is taken.

4.  If RNDIS mode is set then it will create ```android_rndis``` network interface in linux system.

5.  Android Alcatel Tab defaults to creating ```192.168.42.129``` as a RNDIS gateway. Since it is an unrooted device, we cannot modify it, and that's why we are using the 42 series in the master IP.

6.  If the Android tablet is disconnected and connected again, the service runs the same as before.

7.  Android uses ```192.168.42.100``` as master IP.
