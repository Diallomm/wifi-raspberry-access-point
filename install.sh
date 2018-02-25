#!/bin/bash
#Author:MAmadou diallo misterdiallo1@gmail.com
#LICENCE:PUBLIC DOMAINE
#this script allow to transform your raspberry pi into wireless acces point
#DON'T MODIFY THE LINE WHERE IT WAS WRITTEN SUDO ECHO !!!!
#NE PAS MODIFIER LA LIGNE OU ON NA ECRIT SUDO ECHO !!!!

echo "Bonjour et bienvenue dans l'installation, nous vérifions si vous étes connecté via le port ethernet"
sleep 2
etat=$(ping -I eth0 -w 3 www.google.com | grep transmitted | gawk '{print $4}')
if [ "$etat" -eq  0 ]; then
  #Message d'avertissement que interfaces wlan0 sera désactivé
      echo " +-+-+-+-+-+-+-+-+-+
 |A|t|t|e|n|t|i|o|n|
 +-+-+-+-+-+-+-+-+-+"
  echo -e "Merci de vous connectez via le port internet (RJ45) parceque l'inteface wifi sera désactivé l'hors de l'installation, donc vous pourrez plus vous connectez à partir du wifi, seulement sur le port ethernet \n"
fi


read -p "Voulez vous continuer l'installation? [Y/n]" reponse
if [[ $reponse =~ ^(Y|y| ) ]];then

  clear
  ###################################### update and install
  echo 'Mise à jour du systéme'
  sleep 1
  sudo apt-get update -y; sudo apt-get upgrade -y
  sudo apt-get install -y hostapd dnsmasq

  ######################################## file configuration
  sudo echo >> /etc/dhcpcd.conf <<EOF
  #choice interface deny
  denyinterfaces wlan0
EOF
  sudo echo >> /etc/network/interfaces <<EOF
  #interfaces(5) file used by ifup(8) and ifdown(8)
  #Please note that this file is written to be used with dhcpcd
  #For static IP, consult /etc/dhcpcd.conf and man dhcpcd.conf
  # Include files from /etc/network/interfaces.d: source-directory /etc/network/interfaces.d
  auto lo
  iface lo inet loopback
  iface eth0 inet manual
  allow-hotplug wlan0
  iface wlan0 inet static
  address 192.168.220.1
  netmask 255.255.255.0
  network 192.168.220.0
  broadcast 192.168.220.255
EOF

  sudo service dhcpcd restart
  sudo ifdown wlan0; sudo ifup wlan0
  ######################################## name and passwd wifi
  read -p 'veuillez entrer le Nom du wifi (SSID): ' name
  lpw=${#passwd}
  while [ "$lpw" -lt 8 ]
  do
  read -p 'Veuillez entrer le mot passe du wifi (8 caracteres min): ' passwd
  lpw=${#passwd}
  done

  ######################################### wifi file configuration
  sudo echo >>  /etc/hostapd/hostapd.conf <<EOF
  interface=wlan0
  driver=nl80211
  hw_mode=g
  channel=6
  ieee80211n=1
  wmm_enabled=1
  ht_capab=[HT40][SHORT-GI-20] [DSSS_CCK-40]
  macaddr_acl=0
  ignore_broadcast_ssid=0
  # Use WPA2
  auth_algs=1
  wpa=2
  wpa_key_mgmt=WPA-PSK
  rsn_pairwise=CCMP
  # This is the name of the network
  ssid=$name
  # The network passphrase
  wpa_passphrase=$passwd
EOF

  sudo echo >> /etc/default/hostapd <<EOF
    # Defaults for hostapd initscript
    #
    # See /usr/share/doc/hostapd/README.Debian for information about alternative
    # methods of managing hostapd.
    #
    # Uncomment and set DAEMON_CONF to the absolute path of a hostapd configuration
    # file and hostapd will be started during system boot. An example configuration
    # file can be found at /usr/share/doc/hostapd/examples/hostapd.conf.gz
    #
    #DAEMON_CONF="/etc/hostapd/hostapd.conf"

    # Additional daemon options to be appended to hostapd command:-
    #       -d   show more debug messages (-dd for even more)
    #       -K   include key data in debug messages
    #       -t   include timestamps in some debug messages
    #
    # Note that -B (daemon mode) and -P (pidfile) options are automatically
    # configured by the init.d script and must not be added to DAEMON_OPTS.
    #
    #DAEMON_OPTS=""
EOF
sudo echo > /etc/init.d/hostapd <<EOF
    #!/bin/sh

    ### BEGIN INIT INFO
    # Provides:             hostapd
    # Required-Start:       $remote_fs
    # Required-Stop:        $remote_fs
    # Should-Start:         $network
    # Should-Stop:
    # Default-Start:        2 3 4 5
    # Default-Stop:         0 1 6
    # Short-Description:    Advanced IEEE 802.11 management daemon
    # Description:          Userspace IEEE 802.11 AP and IEEE 802.1X/WPA/WPA2/EAP
    #                       Authenticator
    ### END INIT INFO

    PATH=/sbin:/bin:/usr/sbin:/usr/bin
    DAEMON_SBIN=/usr/sbin/hostapd
    DAEMON_DEFS=/etc/default/hostapd
    DAEMON_CONF=/etc/hostapd/hostapd.conf
    NAME=hostapd
    DESC="advanced IEEE 802.11 management"
    PIDFILE=/run/hostapd.pid

    [ -x "$DAEMON_SBIN" ] || exit 0
    [ -s "$DAEMON_DEFS" ] && . /etc/default/hostapd
    [ -n "$DAEMON_CONF" ] || exit 0

    DAEMON_OPTS="-B -P $PIDFILE $DAEMON_OPTS $DAEMON_CONF"

    . /lib/lsb/init-functions

    case "$1" in
      start)
            log_daemon_msg "Starting $DESC" "$NAME"
            start-stop-daemon --start --oknodo --quiet --exec "$DAEMON_SBIN" \
                    --pidfile "$PIDFILE" -- $DAEMON_OPTS >/dev/null
            log_end_msg "$?"
            ;;
      stop)
    log_daemon_msg "Stopping $DESC" "$NAME"
            start-stop-daemon --stop --oknodo --quiet --exec "$DAEMON_SBIN" \
                    --pidfile "$PIDFILE"
            log_end_msg "$?"
            ;;
      reload)
            log_daemon_msg "Reloading $DESC" "$NAME"
            start-stop-daemon --stop --signal HUP --exec "$DAEMON_SBIN" \
                    --pidfile "$PIDFILE"
            log_end_msg "$?"
            ;;
      restart|force-reload)
            $0 stop
            sleep 8
            $0 start
            ;;
      status)
            status_of_proc "$DAEMON_SBIN" "$NAME"
            exit $?
            ;;
      *)
            N=/etc/init.d/$NAME
            echo "Usage: $N {start|stop|restart|force-reload|reload|status}" >&2
            exit 1
            ;;
    esac

    exit 0
EOF

  sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

sudo echo > /etc/dnsmasq.conf <<EOF
    interface=wlan0 # Use interface wlan0
    listen-address=192.168.220.1 # Specify the address to listen on
    bind-interfaces # Bind to the interface
    server=8.8.8.8 # Use Google DNS
    domain-needed # Don't forward short names
    bogus-priv # Drop the non-routed address spaces.
    dhcp-range=192.168.220.30,192.168.220.150,12h # IP range and lease time
EOF

  ########################################## dns name in local
  read -p 'Veuillez donner le nom de domaine de nom raspberrypi (dnsname): ' namedns
  sudo echo "192.168.220.1     $namedns" | sudo tee -a /etc/hosts
  ########################################## install apache ?
  read -p "voulez vous installer apache2 ? [Y/n]" response
  if [[ $response =~ ^(Y|y| ) ]]
  then
  sudo apt-get install apache2 -y
  fi
  ########################################## finish configuration
  echo 'Configuration terminer ! Redémarrage du systeme dans 5s'
  sleep 5
  sudo shutdown -r now
else
      echo "Aurevoir revenez quand vous aurez brancher votre cable ethernet (RJ45)"
fi
