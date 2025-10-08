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
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     KNXd Yönetim ve Kontrol Paneli    ║${NC}"
    echo -e "${CYAN}║          Raspberry Pi için            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}\n"
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
        echo "Lütfen 'sudo ./knxd_setup.sh' komutu ile çalıştırın"
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
        echo -e "${CYAN}Mevcut yapılandırma:${NC}"
        cat /etc/knxd.conf
        echo ""
    fi
    
    read -p "KNX IP Router IP adresi (örn: 192.168.1.100): " KNX_IP
    read -p "KNX IP Router portu (varsayılan 3671): " KNX_PORT
    KNX_PORT=${KNX_PORT:-3671}
    
    read -p "KNXd fiziksel adresi (örn: 1.1.250): " PHY_ADDR
    PHY_ADDR=${PHY_ADDR:-1.1.250}
    
    # Config dosyası oluştur
    cat > /etc/knxd.conf << EOF
# KNXd Yapılandırma Dosyası
# Oluşturulma: $(date)

KNXD_OPTS="--eibaddr=PHY_ADDR:-1.1.250 --listen-local=/tmp/knx --trace=5 --error=5 ipt:$KNX_IP:$KNX_PORT" 
EOF

    echo -e "${GREEN}✓ Yapılandırma dosyası oluşturuldu${NC}"
    
    # Systemd servis dosyası
    cat > /etc/systemd/system/knxd.service << EOF
[Unit]
Description=KNX Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/knxd -c /etc/knxd.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable knxd
    
    echo -e "${YELLOW}Servisi yeniden başlatmak ister misiniz? (e/h): ${NC}"
    read restart_service
    if [[ $restart_service =~ ^[Ee]$ ]]; then
        systemctl restart knxd
        sleep 2
        if systemctl is-active --quiet knxd; then
            echo -e "${GREEN}✓ Servis başarıyla başlatıldı${NC}"
        else
            echo -e "${RED}✗ Servis başlatılamadı. Logları kontrol edin.${NC}"
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
    sleep 1
    
    if timeout 5 knxtool groupsocketlisten ip:localhost >/dev/null 2>&1 &
    then
        LISTEN_PID=$!
        sleep 2
        kill $LISTEN_PID 2>/dev/null
        echo -e "${GREEN}✓ KNX bağlantısı başarılı!${NC}"
        echo -e "${GREEN}IP Router ile bağlantı kuruldu.${NC}"
    else
        echo -e "${RED}✗ KNX bağlantısı kurulamadı${NC}"
        echo -e "${YELLOW}Config ayarlarını kontrol edin (Seçenek 3)${NC}"
    fi
}

# 5) Grup Adresi Okuma
read_group() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  GRUP ADRESİ OKUMA${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    read -p "Grup adresi (örn: 1/2/3): " GROUP_ADDR
    
    echo -e "${YELLOW}Okunuyor: $GROUP_ADDR${NC}"
    if knxtool groupread ip:localhost "$GROUP_ADDR"; then
        echo -e "${GREEN}✓ Okuma başarılı${NC}"
    else
        echo -e "${RED}✗ Okuma başarısız${NC}"
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
    if knxtool groupwrite ip:localhost "$GROUP_ADDR" "$VALUE"; then
        echo -e "${GREEN}✓ Yazma başarılı!${NC}"
    else
        echo -e "${RED}✗ Yazma başarısız${NC}"
    fi
}

# 7) Grup Adresleri Dinleme
listen_groups() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  GRUP ADRESLERİ DİNLEME${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}Tüm grup adresleri dinleniyor...${NC}"
    echo -e "${YELLOW}Durdurmak için CTRL+C basın${NC}\n"
    
    knxtool groupsocketlisten ip:localhost
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
            echo -e "${GREEN}✓ Servis başlatıldı${NC}"
            ;;
        2)
            systemctl stop knxd
            echo -e "${GREEN}✓ Servis durduruldu${NC}"
            ;;
        3)
            systemctl restart knxd
            echo -e "${GREEN}✓ Servis yeniden başlatıldı${NC}"
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