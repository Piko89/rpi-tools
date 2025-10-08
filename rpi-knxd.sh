#!/bin/bash

# KNXd Yönetim Scripti
# Raspberry Pi için hazırlanmıştır

set -e

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
show_banner() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     KNXd Yönetim ve Kontrol Paneli    ║${NC}"
    echo -e "${CYAN}║          Raspberry Pi için            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
}

# Ana Menü
show_menu() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ANA MENÜ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}1)${NC} Sistem Durumu"
    echo -e "${BLUE}2)${NC} KNXd Kurulum"
    echo -e "${BLUE}3)${NC} IP Router Yapılandırma"
    echo -e "${BLUE}4)${NC} Bağlantı Testi"
    echo -e "${BLUE}5)${NC} Grup Adresi Okuma"
    echo -e "${BLUE}6)${NC} Grup Adresi Yazma"
    echo -e "${BLUE}7)${NC} Grup Adresleri Dinleme"
    echo -e "${BLUE}8)${NC} Servis Yönetimi"
    echo -e "${BLUE}9)${NC} Logları Görüntüle"
    echo -e "${BLUE}0)${NC} Çıkış"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Root kontrolü
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Bu script root yetkisi ile çalıştırılmalıdır!${NC}"
        echo "Lütfen 'sudo ./rpi-knxd.sh' komutu ile çalıştırın"
        exit 1
    fi
}

# 1) Sistem Durumu
check_status() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SİSTEM DURUMU${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    # KNXd kurulu mu?
    if command -v knxd &> /dev/null; then
        echo -e "${GREEN}✓ KNXd Kurulu${NC}"
        knxd --version 2>/dev/null || echo "Versiyon bilgisi alınamadı"
    else
        echo -e "${RED}✗ KNXd Kurulu Değil${NC}"
    fi
    
    echo ""
    
    # Servis durumu
    if systemctl list-unit-files | grep -q knxd.service; then
        echo -e "${GREEN}✓ KNXd Servisi Mevcut${NC}"
        if systemctl is-active --quiet knxd; then
            echo -e "${GREEN}✓ Servis Çalışıyor${NC}"
        else
            echo -e "${RED}✗ Servis Durmuş${NC}"
        fi
        
        if systemctl is-enabled --quiet knxd; then
            echo -e "${GREEN}✓ Otomatik Başlatma Aktif${NC}"
        else
            echo -e "${YELLOW}⚠ Otomatik Başlatma Pasif${NC}"
        fi
    else
        echo -e "${RED}✗ KNXd Servisi Bulunamadı${NC}"
    fi
    
    echo ""
    
    # Config dosyası
    if [ -f /etc/knxd.conf ]; then
        echo -e "${GREEN}✓ Config Dosyası Mevcut${NC}"
        echo -e "${CYAN}Config: /etc/knxd.conf${NC}"
        echo ""
        cat /etc/knxd.conf
    else
        echo -e "${RED}✗ Config Dosyası Bulunamadı${NC}"
    fi
    
    # Default config dosyası (varsa)
    if [ -f /etc/default/knxd ]; then
        echo ""
        echo -e "${GREEN}✓ Default Config Dosyası Mevcut${NC}"
        echo -e "${CYAN}Config: /etc/default/knxd${NC}"
        echo ""
        cat /etc/default/knxd
    fi
    
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
}

# 2) KNXd Kurulum
install_knxd() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  KNXd KURULUM${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    if command -v knxd &> /dev/null; then
        echo -e "${GREEN}✓ KNXd zaten kurulu${NC}"
        knxd --version
        read -p "Yeniden kurmak ister misiniz? (e/h): " reinstall
        if [[ ! $reinstall =~ ^[Ee]$ ]]; then
            return
        fi
    fi
    
    echo -e "${YELLOW}Sistem güncelleniyor...${NC}"
    apt-get update
    
    echo -e "${YELLOW}KNXd ve araçları kuruluyor...${NC}"
    apt-get install -y knxd knxd-tools
    
    echo -e "${GREEN}✓ KNXd başarıyla kuruldu!${NC}"
    knxd --version
}

# 3) IP Router Yapılandırma
configure_router() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  IP ROUTER YAPILANDIRMA${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    # Mevcut config varsa göster
    if [ -f /etc/knxd.conf ]; then
        echo -e "${CYAN}Mevcut knxd.conf yapılandırması:${NC}"
        cat /etc/knxd.conf
        echo ""
    fi
    
    if [ -f /etc/default/knxd ]; then
        echo -e "${CYAN}Mevcut /etc/default/knxd yapılandırması:${NC}"
        cat /etc/default/knxd
        echo ""
    fi
    
    read -p "KNX IP Router IP adresi (örn: 192.168.1.100): " KNX_IP
    read -p "KNX IP Router portu (varsayılan 3671): " KNX_PORT
    KNX_PORT=${KNX_PORT:-3671}
    
    read -p "KNXd fiziksel adresi (örn: 1.1.250): " PHY_ADDR
    PHY_ADDR=${PHY_ADDR:-1.1.250}
    
    read -p "Client adres aralığı (örn: 1.1.251:8): " CLIENT_ADDR
    CLIENT_ADDR=${CLIENT_ADDR:-1.1.251:8}
    
    echo ""
    echo -e "${YELLOW}Yapılandırma yöntemi seçin:${NC}"
    echo -e "${BLUE}1)${NC} Yeni format (KNXD_OPTS - Önerilen)"
    echo -e "${BLUE}2)${NC} Eski format (KNXD_OPTIONS)"
    read -p "Seçiminiz (1/2): " config_format
    
    # /etc/default/knxd dosyası oluştur
    if [[ $config_format == "1" ]]; then
        # Yeni format
        cat > /etc/default/knxd << EOF
# KNXd Yapılandırma Dosyası (Yeni Format)
# Oluşturulma: $(date)

KNXD_OPTS="--eibaddr=$PHY_ADDR --client-addrs=$CLIENT_ADDR --listen-local=/tmp/knx --trace=5 --error=5 ipt:$KNX_IP:$KNX_PORT"
EOF
    else
        # Eski format
        cat > /etc/default/knxd << EOF
# KNXd Yapılandırma Dosyası (Eski Format)
# Oluşturulma: $(date)

KNXD_OPTIONS="-e $PHY_ADDR -E $CLIENT_ADDR -D -T -R -S -i --listen-local=/tmp/knx -b ipt:$KNX_IP:$KNX_PORT"
EOF
    fi
    
    echo -e "${GREEN}✓ /etc/default/knxd dosyası oluşturuldu${NC}"
    
    # /etc/knxd.conf dosyası oluştur (alternatif format)
    cat > /etc/knxd.conf << EOF
# KNXd INI Formatı Yapılandırma
# Oluşturulma: $(date)

[main]
addr = $PHY_ADDR
client-addrs = $CLIENT_ADDR
connections = router
logfile = /var/log/knxd.log

[A]
driver = ipt
ip-address = $KNX_IP
dest-port = $KNX_PORT

[router]
driver = router
addr = 0.0.1
device = A
name = router
EOF

    echo -e "${GREEN}✓ /etc/knxd.conf dosyası oluşturuldu${NC}"
    
    # Systemd servis dosyası
    cat > /etc/systemd/system/knxd.service << EOF
[Unit]
Description=KNX Daemon
After=network.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/knxd
ExecStart=/usr/bin/knxd \$KNXD_OPTS
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✓ Systemd servis dosyası oluşturuldu${NC}"
    
    systemctl daemon-reload
    systemctl enable knxd
    
    echo ""
    echo -e "${YELLOW}Yapılandırma tamamlandı!${NC}"
    echo ""
    echo -e "${CYAN}Oluşturulan dosyalar:${NC}"
    echo "  - /etc/default/knxd (Ana yapılandırma)"
    echo "  - /etc/knxd.conf (Alternatif yapılandırma)"
    echo "  - /etc/systemd/system/knxd.service"
    echo ""
    
    read -p "Servisi yeniden başlatmak ister misiniz? (e/h): " restart_service
    if [[ $restart_service =~ ^[Ee]$ ]]; then
        systemctl restart knxd
        sleep 2
        if systemctl is-active --quiet knxd; then
            echo -e "${GREEN}✓ Servis başarıyla başlatıldı${NC}"
        else
            echo -e "${RED}✗ Servis başlatılamadı. Logları kontrol edin:${NC}"
            echo "  journalctl -u knxd -n 20"
        fi
    fi
}

# 4) Bağlantı Testi
test_connection() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  BAĞLANTI TESTİ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    if ! systemctl is-active --quiet knxd; then
        echo -e "${RED}✗ KNXd servisi çalışmıyor!${NC}"
        echo -e "${YELLOW}Önce servisi başlatın (Seçenek 8)${NC}"
        return
    fi
    
    echo -e "${YELLOW}KNX bağlantısı test ediliyor...${NC}"
    echo -e "${CYAN}Socket: /tmp/knx${NC}"
    sleep 1
    
    # Socket var mı kontrol et
    if [ ! -S /tmp/knx ]; then
        echo -e "${RED}✗ KNX socket bulunamadı (/tmp/knx)${NC}"
        echo -e "${YELLOW}Servisi yeniden başlatmayı deneyin${NC}"
        return
    fi
    
    echo -e "${GREEN}✓ KNX socket mevcut${NC}"
    
    # Bağlantı testi
    if timeout 5 knxtool groupsocketlisten local:/tmp/knx >/dev/null 2>&1 &
    then
        LISTEN_PID=$!
        sleep 2
        kill $LISTEN_PID 2>/dev/null
        echo -e "${GREEN}✓ KNX bağlantısı başarılı!${NC}"
        echo -e "${GREEN}IP Router ile bağlantı kuruldu.${NC}"
    else
        echo -e "${RED}✗ KNX bağlantısı kurulamadı${NC}"
        echo -e "${YELLOW}Logları kontrol edin: journalctl -u knxd -n 50${NC}"
    fi
}

# 5) Grup Adresi Okuma
read_group() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  GRUP ADRESİ OKUMA${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    read -p "Grup adresi (örn: 1/2/3): " GROUP_ADDR
    
    echo -e "${YELLOW}Okunuyor: $GROUP_ADDR${NC}"
    if knxtool groupread local:/tmp/knx "$GROUP_ADDR"; then
        echo -e "${GREEN}✓ Okuma başarılı${NC}"
    else
        echo -e "${RED}✗ Okuma başarısız${NC}"
        echo -e "${YELLOW}Socket kontrolü: ls -la /tmp/knx${NC}"
    fi
}

# 6) Grup Adresi Yazma
write_group() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  GRUP ADRESİ YAZMA${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    read -p "Grup adresi (örn: 1/2/3): " GROUP_ADDR
    read -p "Değer (0 veya 1): " VALUE
    
    echo -e "${YELLOW}Yazılıyor: $GROUP_ADDR = $VALUE${NC}"
    if knxtool groupwrite local:/tmp/knx "$GROUP_ADDR" "$VALUE"; then
        echo -e "${GREEN}✓ Yazma başarılı!${NC}"
    else
        echo -e "${RED}✗ Yazma başarısız${NC}"
        echo -e "${YELLOW}Socket kontrolü: ls -la /tmp/knx${NC}"
    fi
}

# 7) Grup Adresleri Dinleme
listen_groups() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  GRUP ADRESLERİ DİNLEME${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}Tüm grup adresleri dinleniyor...${NC}"
    echo -e "${YELLOW}Durdurmak için CTRL+C basın${NC}\n"
    
    knxtool groupsocketlisten local:/tmp/knx
}

# 8) Servis Yönetimi
manage_service() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SERVİS YÖNETİMİ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    echo -e "${BLUE}1)${NC} Servisi Başlat"
    echo -e "${BLUE}2)${NC} Servisi Durdur"
    echo -e "${BLUE}3)${NC} Servisi Yeniden Başlat"
    echo -e "${BLUE}4)${NC} Servis Durumu"
    echo -e "${BLUE}5)${NC} Otomatik Başlatmayı Aç"
    echo -e "${BLUE}6)${NC} Otomatik Başlatmayı Kapat"
    echo ""
    read -p "Seçiminiz: " service_choice
    
    case $service_choice in
        1)
            systemctl start knxd
            sleep 2
            if systemctl is-active --quiet knxd; then
                echo -e "${GREEN}✓ Servis başlatıldı${NC}"
            else
                echo -e "${RED}✗ Servis başlatılamadı${NC}"
                journalctl -u knxd -n 10 --no-pager
            fi
            ;;
        2)
            systemctl stop knxd
            echo -e "${GREEN}✓ Servis durduruldu${NC}"
            ;;
        3)
            systemctl restart knxd
            sleep 2
            if systemctl is-active --quiet knxd; then
                echo -e "${GREEN}✓ Servis yeniden başlatıldı${NC}"
            else
                echo -e "${RED}✗ Servis başlatılamadı${NC}"
                journalctl -u knxd -n 10 --no-pager
            fi
            ;;
        4)
            systemctl status knxd
            ;;
        5)
            systemctl enable knxd
            echo -e "${GREEN}✓ Otomatik başlatma aktif${NC}"
            ;;
        6)
            systemctl disable knxd
            echo -e "${GREEN}✓ Otomatik başlatma pasif${NC}"
            ;;
        *)
            echo -e "${RED}Geçersiz seçim${NC}"
            ;;
    esac
}

# 9) Logları Görüntüle
view_logs() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  LOGLARI GÖRÜNTÜLE${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    echo -e "${BLUE}1)${NC} Son 50 satır"
    echo -e "${BLUE}2)${NC} Canlı log takibi (CTRL+C ile çık)"
    echo -e "${BLUE}3)${NC} Tüm loglar"
    echo -e "${BLUE}4)${NC} Sadece hata logları"
    echo ""
    read -p "Seçiminiz: " log_choice
    
    case $log_choice in
        1)
            journalctl -u knxd -n 50 --no-pager
            ;;
        2)
            echo -e "${YELLOW}Canlı log takibi... (CTRL+C ile çıkın)${NC}\n"
            journalctl -u knxd -f
            ;;
        3)
            journalctl -u knxd --no-pager
            ;;
        4)
            journalctl -u knxd -p err --no-pager
            ;;
        *)
            echo -e "${RED}Geçersiz seçim${NC}"
            ;;
    esac
}

# Ana döngü
main() {
    check_root
    
    while true; do
        show_banner
        show_menu
        
        read -p "Seçiminiz (0-9): " choice
        
        case $choice in
            1)
                check_status
                ;;
            2)
                install_knxd
                ;;
            3)
                configure_router
                ;;
            4)
                test_connection
                ;;
            5)
                read_group
                ;;
            6)
                write_group
                ;;
            7)
                listen_groups
                ;;
            8)
                manage_service
                ;;
            9)
                view_logs
                ;;
            0)
                echo -e "\n${GREEN}Çıkılıyor... Hoşça kalın!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Geçersiz seçim! Lütfen 0-9 arası bir değer girin.${NC}"
                ;;
        esac
        
        echo -e "\n${CYAN}Devam etmek için Enter tuşuna basın...${NC}"
        read
    done
}

# Programı başlat
main