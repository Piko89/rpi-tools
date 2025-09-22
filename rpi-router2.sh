#!/bin/bash

# WiFi to Ethernet Bridge Script for Raspberry Pi 5
# Kullanım: ./wifi_ethernet_bridge.sh [start|stop|status|config]

# Konfigürasyon değişkenleri
WIFI_INTERFACE="wlan0"
ETH_INTERFACE="eth0"
BRIDGE_IP="192.168.1.1"
BRIDGE_SUBNET="192.168.1.1/24"
DHCP_RANGE_START="192.168.1.10"
DHCP_RANGE_END="192.168.1.50"
DHCP_LEASE_TIME="12h"

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log dosyası
LOG_FILE="/var/log/wifi_bridge.log"

# Root yetkisi kontrolü
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Bu script root yetkisiyle çalıştırılmalıdır. 'sudo' kullanın.${NC}"
        exit 1
    fi
}

# Gerekli paketlerin kontrolü ve kurulumu
check_dependencies() {
    echo -e "${BLUE}Gerekli paketler kontrol ediliyor...${NC}"
    
    packages=("dnsmasq" "iptables" "hostapd")
    missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "${YELLOW}Eksik paketler kuruluyor: ${missing_packages[*]}${NC}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
    fi
}

# Log fonksiyonu
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Ağ arayüzlerinin durumunu kontrol et
check_interfaces() {
    echo -e "${BLUE}Ağ arayüzleri kontrol ediliyor...${NC}"
    
    if ! ip link show "$WIFI_INTERFACE" &>/dev/null; then
        echo -e "${RED}WiFi arayüzü ($WIFI_INTERFACE) bulunamadı!${NC}"
        exit 1
    fi
    
    if ! ip link show "$ETH_INTERFACE" &>/dev/null; then
        echo -e "${RED}Ethernet arayüzü ($ETH_INTERFACE) bulunamadı!${NC}"
        exit 1
    fi
    
    # WiFi bağlantısını kontrol et
    if ! iwgetid "$WIFI_INTERFACE" &>/dev/null; then
        echo -e "${YELLOW}Uyarı: WiFi bağlantısı tespit edilemedi!${NC}"
    fi
}

# dnsmasq konfigürasyonu
configure_dnsmasq() {
    echo -e "${BLUE}dnsmasq konfigürasyonu hazırlanıyor...${NC}"
    
    cat > /etc/dnsmasq.conf << EOF
# WiFi Bridge için dnsmasq konfigürasyonu
interface=$ETH_INTERFACE
bind-interfaces
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$DHCP_LEASE_TIME
dhcp-option=3,$BRIDGE_IP
dhcp-option=6,$BRIDGE_IP
server=8.8.8.8
server=8.8.4.4
log-queries
log-dhcp
EOF
}

# IP forwarding'i etkinleştir
enable_ip_forwarding() {
    echo -e "${BLUE}IP forwarding etkinleştiriliyor...${NC}"
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ip-forward.conf
    sysctl -p /etc/sysctl.d/99-ip-forward.conf
}

# iptables kurallarını ayarla
setup_iptables() {
    echo -e "${BLUE}iptables kuralları ayarlanıyor...${NC}"
    
    # Mevcut kuralları temizle
    iptables -t nat -F
    iptables -t nat -X
    iptables -F
    iptables -X
    
    # NAT kuralları
    iptables -t nat -A POSTROUTING -o "$WIFI_INTERFACE" -j MASQUERADE
    iptables -A FORWARD -i "$WIFI_INTERFACE" -o "$ETH_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$ETH_INTERFACE" -o "$WIFI_INTERFACE" -j ACCEPT
    
    # Kuralları kaydet
    iptables-save > /etc/iptables/rules.v4
}

# Ethernet arayüzünü yapılandır
configure_ethernet() {
    echo -e "${BLUE}Ethernet arayüzü yapılandırılıyor...${NC}"
    
    # Statik IP ata
    ip addr flush dev "$ETH_INTERFACE"
    ip addr add "$BRIDGE_IP/24" dev "$ETH_INTERFACE"
    ip link set "$ETH_INTERFACE" up
}

# Bridge'i başlat
start_bridge() {
    echo -e "${GREEN}WiFi to Ethernet Bridge başlatılıyor...${NC}"
    
    check_root
    check_dependencies
    check_interfaces
    
    # Servisleri durdur
    systemctl stop dnsmasq 2>/dev/null
    
    configure_ethernet
    enable_ip_forwarding
    setup_iptables
    configure_dnsmasq
    
    # dnsmasq'ı başlat
    systemctl start dnsmasq
    systemctl enable dnsmasq
    
    log_message "Bridge başlatıldı"
    echo -e "${GREEN}Bridge başarıyla başlatıldı!${NC}"
    echo -e "${BLUE}Ethernet IP: $BRIDGE_IP${NC}"
    echo -e "${BLUE}DHCP Aralığı: $DHCP_RANGE_START - $DHCP_RANGE_END${NC}"
}

# Bridge'i durdur
stop_bridge() {
    echo -e "${YELLOW}WiFi to Ethernet Bridge durduruluyor...${NC}"
    
    check_root
    
    # Servisleri durdur
    systemctl stop dnsmasq
    systemctl disable dnsmasq
    
    # iptables kurallarını temizle
    iptables -t nat -F
    iptables -F
    
    # Ethernet arayüzünü temizle
    ip addr flush dev "$ETH_INTERFACE"
    ip link set "$ETH_INTERFACE" down
    
    log_message "Bridge durduruldu"
    echo -e "${GREEN}Bridge başarıyla durduruldu!${NC}"
}

# Durum kontrolü
check_status() {
    echo -e "${BLUE}=== WiFi to Ethernet Bridge Durumu ===${NC}"
    
    # Servis durumu
    echo -e "\n${BLUE}Servis Durumu:${NC}"
    if systemctl is-active --quiet dnsmasq; then
        echo -e "dnsmasq: ${GREEN}Çalışıyor${NC}"
    else
        echo -e "dnsmasq: ${RED}Durduruldu${NC}"
    fi
    
    # IP forwarding durumu
    echo -e "\n${BLUE}IP Forwarding:${NC}"
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]; then
        echo -e "Status: ${GREEN}Etkin${NC}"
    else
        echo -e "Status: ${RED}Deaktif${NC}"
    fi
    
    # Ağ arayüzleri
    echo -e "\n${BLUE}Ağ Arayüzleri:${NC}"
    echo -e "WiFi ($WIFI_INTERFACE):"
    if ip addr show "$WIFI_INTERFACE" | grep -q "state UP"; then
        wifi_ip=$(ip addr show "$WIFI_INTERFACE" | grep 'inet ' | awk '{print $2}' | head -n1)
        echo -e "  Durum: ${GREEN}UP${NC}, IP: ${wifi_ip:-"Yok"}"
    else
        echo -e "  Durum: ${RED}DOWN${NC}"
    fi
    
    echo -e "Ethernet ($ETH_INTERFACE):"
    if ip addr show "$ETH_INTERFACE" | grep -q "state UP"; then
        eth_ip=$(ip addr show "$ETH_INTERFACE" | grep 'inet ' | awk '{print $2}' | head -n1)
        echo -e "  Durum: ${GREEN}UP${NC}, IP: ${eth_ip:-"Yok"}"
    else
        echo -e "  Durum: ${RED}DOWN${NC}"
    fi
    
    # iptables kuralları
    echo -e "\n${BLUE}iptables NAT Kuralları:${NC}"
    nat_rules=$(iptables -t nat -L POSTROUTING | grep -c MASQUERADE)
    if [ "$nat_rules" -gt 0 ]; then
        echo -e "NAT Kuralları: ${GREEN}$nat_rules kural aktif${NC}"
    else
        echo -e "NAT Kuralları: ${RED}Kural yok${NC}"
    fi
    
    # DHCP kiraları
    echo -e "\n${BLUE}DHCP Kiraları:${NC}"
    if [ -f "/var/lib/dhcp/dhcpd.leases" ] || [ -f "/var/lib/dhcpcd5/dhcpcd.leases" ]; then
        lease_count=$(grep -c "lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null || echo "0")
        echo -e "Aktif kira sayısı: $lease_count"
    else
        echo -e "DHCP kira bilgisi bulunamadı"
    fi
    
    # Son loglar
    echo -e "\n${BLUE}Son Log Kayıtları:${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -5 "$LOG_FILE"
    else
        echo -e "${YELLOW}Log dosyası bulunamadı${NC}"
    fi
}

# Konfigürasyon ayarları
configure_settings() {
    echo -e "${BLUE}=== Konfigürasyon Ayarları ===${NC}"
    echo -e "${YELLOW}Mevcut ayarlar:${NC}"
    echo "WiFi Arayüzü: $WIFI_INTERFACE"
    echo "Ethernet Arayüzü: $ETH_INTERFACE"
    echo "Bridge IP: $BRIDGE_IP"
    echo "DHCP Aralığı: $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo "DHCP Kira Süresi: $DHCP_LEASE_TIME"
    
    echo -e "\n${BLUE}Ayarları değiştirmek için script'in başındaki değişkenleri düzenleyin.${NC}"
}

# Kullanım bilgisi
show_usage() {
    echo -e "${BLUE}Kullanım:${NC} $0 [start|stop|status|config]"
    echo
    echo -e "${BLUE}Komutlar:${NC}"
    echo -e "  ${GREEN}start${NC}   - WiFi to Ethernet bridge'i başlat"
    echo -e "  ${GREEN}stop${NC}    - Bridge'i durdur"
    echo -e "  ${GREEN}status${NC}  - Bridge durumunu göster"
    echo -e "  ${GREEN}config${NC}  - Konfigürasyon ayarlarını göster"
    echo
    echo -e "${BLUE}Örnekler:${NC}"
    echo -e "  sudo $0 start"
    echo -e "  sudo $0 status"
}

# Ana fonksiyon
main() {
    case "${1:-}" in
        start)
            start_bridge
            ;;
        stop)
            stop_bridge
            ;;
        status)
            check_status
            ;;
        config)
            configure_settings
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
