#!/bin/bash
#
# Raspberry Pi Router Kontrol Scripti
#
# Kullanım:
#   sudo ./rpi-router.sh start      -> Router modunu başlat (static IP + DHCP server + NAT)
#   sudo ./rpi-router.sh stop       -> Router modunu durdur
#   sudo ./rpi-router.sh dhcp-on    -> Sadece DHCP sunucusunu aç
#   sudo ./rpi-router.sh dhcp-off   -> Sadece DHCP sunucusunu kapat
#   sudo ./rpi-router.sh nat-on     -> NAT yönlendirmeyi aç
#   sudo ./rpi-router.sh nat-off    -> NAT yönlendirmeyi kapat
#   sudo ./rpi-router.sh ip-static  -> eth0’a statik IP (192.168.1.1/24) ata
#   sudo ./rpi-router.sh ip-dhcp    -> eth0’u DHCP client moduna geçir
#   sudo ./rpi-router.sh status     -> Tüm durum bilgilerini göster
#
# Not: ip-static / ip-dhcp ile arayüz IP’sini, dhcp-on / dhcp-off ile DHCP sunucusunu kontrol ediyorsun.
#

# Ayarlar
ETH_INTERFACE="eth0"
WLAN_INTERFACE="wlan0"
STATIC_IP="192.168.1.1/24"
DHCP_CONF="/etc/dnsmasq.conf"

# --- Durum Fonksiyonu ---
show_status() {
    echo "====== DURUM BİLGİSİ ======"
    # IP bilgisi
    IP_INFO=$(ip -4 addr show $ETH_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "Yok")
    echo "- $ETH_INTERFACE IP: $IP_INFO"

    # Static / DHCP modu tespiti
    if [[ "$IP_INFO" == "$STATIC_IP" ]]; then
        echo "- IP modu: STATIC ($STATIC_IP)"
    elif [[ "$IP_INFO" == "Yok" ]]; then
        echo "- IP modu: Kapalı"
    else
        echo "- IP modu: DHCP (veya farklı static)"
    fi

    # IP yönlendirme
    echo "- IP yönlendirme: $(cat /proc/sys/net/ipv4/ip_forward)"

    # DHCP sunucu durumu
    echo "- DHCP sunucusu: $(systemctl is-active dnsmasq 2>/dev/null)"

    # NAT durumu
    echo "- NAT tablosu:"
    sudo iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE || echo "Yok"
    echo "=========================="

    # IP bilgisi
    ETH_IP=$(ip -4 addr show $ETH_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "Yok")
    WLAN_IP=$(ip -4 addr show $WLAN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "Yok")
    echo "- $ETH_INTERFACE IP: $ETH_IP"
    echo "- $WLAN_INTERFACE IP: $WLAN_IP"
    echo "=========================="
}

# --- DHCP Sunucusu Kontrolü ---
enable_dhcp() {
    if ! grep -q "interface=$ETH_INTERFACE" $DHCP_CONF; then
        echo "interface=$ETH_INTERFACE" | sudo tee -a $DHCP_CONF
        echo "dhcp-range=192.168.1.10,192.168.1.100,255.255.255.0,24h" | sudo tee -a $DHCP_CONF
    fi
    sudo systemctl restart dnsmasq
    echo "[OK] DHCP sunucusu açıldı"
}

disable_dhcp() {
    sudo systemctl stop dnsmasq
    echo "[OK] DHCP sunucusu kapatıldı"
}

# --- NAT Kontrolü ---
enable_nat() {
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null
    sudo iptables -t nat -C POSTROUTING -o $WLAN_INTERFACE -j MASQUERADE 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -o $WLAN_INTERFACE -j MASQUERADE
    echo "[OK] NAT yönlendirme açıldı"
}

disable_nat() {
    echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null
    sudo iptables -t nat -D POSTROUTING -o $WLAN_INTERFACE -j MASQUERADE 2>/dev/null
    echo "[OK] NAT yönlendirme kapatıldı"
}

# --- IP Modu Kontrolü ---
set_ip_static() {
    sudo ip addr flush dev $ETH_INTERFACE
    sudo ip addr add $STATIC_IP dev $ETH_INTERFACE
    sudo ip link set $ETH_INTERFACE up
    echo "[OK] $ETH_INTERFACE arayüzüne $STATIC_IP atandı (Static Mode)"
}

set_ip_dhcp() {
    sudo dhclient -r $ETH_INTERFACE 2>/dev/null
    sudo ip addr flush dev $ETH_INTERFACE
    sudo dhclient $ETH_INTERFACE
    echo "[OK] $ETH_INTERFACE DHCP üzerinden IP alıyor"
}

# --- Ana Komutlar ---
case "$1" in
    start)
        set_ip_static
        enable_dhcp
        enable_nat
        show_status
        ;;
    stop)
        disable_dhcp
        disable_nat
        echo "[OK] Router servisi durduruldu"
        show_status
        ;;
    dhcp-on)
        enable_dhcp
        ;;
    dhcp-off)
        disable_dhcp
        ;;
    nat-on)
        enable_nat
        ;;
    nat-off)
        disable_nat
        ;;
    ip-static)
        set_ip_static
        ;;
    ip-dhcp)
        set_ip_dhcp
        ;;
    status)
        show_status
        ;;
    *)
        echo "Kullanım: $0 {start|stop|dhcp-on|dhcp-off|nat-on|nat-off|ip-static|ip-dhcp|status}"
        ;;
esac
