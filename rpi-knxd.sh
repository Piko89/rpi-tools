#!/bin/bash

# KNX USB Interface Yönetim Scripti
# Raspberry Pi için knxd kurulum ve yönetim aracı
# Kullanım: ./knx_manager.sh [install|start|stop|status|restart|config|uninstall]

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Renk sıfırla

# Log dosyası
LOG_FILE="/var/log/knxd.log"
CONFIG_FILE="/etc/knxd.conf"
SERVICE_FILE="/etc/systemd/system/knxd.service"

# Fonksiyonlar
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Root kontrolü
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Bu script root yetkisi ile çalıştırılmalıdır."
        echo "Kullanım: sudo $0 $1"
        exit 1
    fi
}

# USB cihaz kontrolü
check_usb_device() {
    print_status "KNX USB interface aranıyor..."
    
    # Yaygın KNX USB interface vendor ID'leri
    KNX_VENDORS=("0e77" "135e" "16d0" "147b")
    
    for vendor in "${KNX_VENDORS[@]}"; do
        if lsusb | grep -i "$vendor" > /dev/null; then
            USB_DEVICE=$(lsusb | grep -i "$vendor")
            print_success "KNX USB interface bulundu: $USB_DEVICE"
            return 0
        fi
    done
    
    print_warning "Belirli bir KNX USB interface bulunamadı."
    print_status "Bağlı tüm USB cihazlar:"
    lsusb
    return 1
}

# Bağımlılık kontrolü ve kurulum
install_dependencies() {
    print_status "Sistem güncelleniyor..."
    apt update
    
    print_status "Gerekli paketler kuruluyor..."
    apt install -y build-essential cmake git pkg-config \
                   libusb-1.0-0-dev libsystemd-dev \
                   libudev-dev libfmt-dev \
                   systemd-dev
    
    if [ $? -eq 0 ]; then
        print_success "Bağımlılıklar başarıyla kuruldu"
    else
        print_error "Bağımlılık kurulumunda hata oluştu"
        return 1
    fi
}

# knxd kurulum
install_knxd() {
    check_root "install"
    
    print_status "knxd kurulum başlatılıyor..."
    
    # Mevcut kurulum kontrolü
    if command -v knxd &> /dev/null; then
        print_warning "knxd zaten kurulu. Yeniden kurmak için önce kaldırın."
        read -p "Mevcut kurulumu kaldırıp yeniden kurmak istiyor musunuz? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_knxd
        else
            return 0
        fi
    fi
    
    install_dependencies
    
    # knxd kaynak kodunu indir
    print_status "knxd kaynak kodu indiriliyor..."
    cd /tmp
    rm -rf knxd
    git clone https://github.com/knxd/knxd.git
    cd knxd
    
    # Derleme ve kurulum
    print_status "knxd derleniyor..."
    mkdir build
    cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
    make -j$(nproc)
    
    if [ $? -eq 0 ]; then
        print_status "knxd kuruluyor..."
        make install
        ldconfig
        
        # Systemd servis dosyası oluştur
        create_service_file
        
        # Varsayılan config dosyası oluştur
        create_default_config
        
        print_success "knxd başarıyla kuruldu"
    else
        print_error "knxd derlemesinde hata oluştu"
        return 1
    fi
    
    # Cleanup
    cd /
    rm -rf /tmp/knxd
}

# Systemd servis dosyası oluştur
create_service_file() {
    print_status "Systemd servis dosyası oluşturuluyor..."
    
    cat > $SERVICE_FILE << 'EOF'
[Unit]
Description=KNX Daemon
After=network.target
Wants=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/knxd --config=/etc/knxd.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
User=knxd
Group=knxd
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # knxd kullanıcısı oluştur
    if ! id "knxd" &>/dev/null; then
        print_status "knxd kullanıcısı oluşturuluyor..."
        useradd -r -s /bin/false knxd
    fi
    
    systemctl daemon-reload
    print_success "Systemd servis dosyası oluşturuldu"
}

# Varsayılan config dosyası oluştur
create_default_config() {
    print_status "Varsayılan konfigürasyon dosyası oluşturuluyor..."
    
    cat > $CONFIG_FILE << 'EOF'
# KNX Daemon Configuration
# USB Interface Configuration

[main]
addr = 1.1.128
client-addrs = 1.1.129:8

[A.usb]
device = /dev/ttyACM0
driver = ft12cemi

[server]
interface = usb
name = knxd_server
systemd-ignore = false

[debug]
error-level = warning
trace-mask = 0

# Uncomment and modify these lines for your specific USB device:
# [A.usb]
# device = auto
# driver = auto
EOF
    
    print_success "Konfigürasyon dosyası oluşturuldu: $CONFIG_FILE"
}

# knxd başlat
start_knxd() {
    check_root "start"
    
    print_status "knxd başlatılıyor..."
    
    if ! command -v knxd &> /dev/null; then
        print_error "knxd kurulu değil. Önce kurulum yapın: $0 install"
        return 1
    fi
    
    systemctl start knxd
    systemctl enable knxd
    
    if [ $? -eq 0 ]; then
        print_success "knxd başlatıldı ve otomatik başlatma etkinleştirildi"
    else
        print_error "knxd başlatılamadı"
        print_status "Hata detayları için: journalctl -u knxd -f"
    fi
}

# knxd durdur
stop_knxd() {
    check_root "stop"
    
    print_status "knxd durduruluyor..."
    
    systemctl stop knxd
    systemctl disable knxd
    
    if [ $? -eq 0 ]; then
        print_success "knxd durduruldu ve otomatik başlatma devre dışı bırakıldı"
    else
        print_error "knxd durdurulamadı"
    fi
}

# knxd yeniden başlat
restart_knxd() {
    check_root "restart"
    
    print_status "knxd yeniden başlatılıyor..."
    
    systemctl restart knxd
    
    if [ $? -eq 0 ]; then
        print_success "knxd yeniden başlatıldı"
    else
        print_error "knxd yeniden başlatılamadı"
    fi
}

# knxd durum
status_knxd() {
    print_status "knxd durum bilgisi:"
    echo "========================"
    
    # Kurulum durumu
    if command -v knxd &> /dev/null; then
        VERSION=$(knxd --version 2>&1 | head -n1)
        print_success "knxd kurulu: $VERSION"
    else
        print_error "knxd kurulu değil"
        return 1
    fi
    
    # Servis durumu
    if systemctl is-active --quiet knxd; then
        print_success "Servis durumu: ÇALIŞIYOR"
    else
        print_error "Servis durumu: DURMUŞ"
    fi
    
    # Otomatik başlatma durumu
    if systemctl is-enabled --quiet knxd; then
        print_success "Otomatik başlatma: ETKİN"
    else
        print_warning "Otomatik başlatma: DEVRE DIŞI"
    fi
    
    # USB cihaz durumu
    check_usb_device
    
    # Son 10 log satırı
    if [ -f "$LOG_FILE" ]; then
        echo
        print_status "Son log kayıtları:"
        tail -n 10 "$LOG_FILE"
    fi
    
    echo
    print_status "Detaylı log için: journalctl -u knxd -f"
}

# Konfigürasyon editörü
config_knxd() {
    check_root "config"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Konfigürasyon dosyası bulunamadı: $CONFIG_FILE"
        print_status "Önce knxd kurulumu yapın: $0 install"
        return 1
    fi
    
    echo "========================"
    print_status "KNX Konfigürasyon Menüsü"
    echo "========================"
    echo "1) Konfigürasyonu düzenle"
    echo "2) Konfigürasyonu görüntüle"
    echo "3) USB cihaz ayarları"
    echo "4) Server ayarları"
    echo "5) Debug ayarları"
    echo "6) Varsayılan konfigürasyonu yükle"
    echo "0) Ana menüye dön"
    echo
    
    read -p "Seçiminiz (0-6): " choice
    
    case $choice in
        1)
            if command -v nano &> /dev/null; then
                nano "$CONFIG_FILE"
            elif command -v vi &> /dev/null; then
                vi "$CONFIG_FILE"
            else
                print_error "Metin editörü bulunamadı"
            fi
            ;;
        2)
            print_status "Mevcut konfigürasyon:"
            cat "$CONFIG_FILE"
            ;;
        3)
            configure_usb_device
            ;;
        4)
            configure_server
            ;;
        5)
            configure_debug
            ;;
        6)
            create_default_config
            ;;
        0|*)
            return 0
            ;;
    esac
}

# USB cihaz konfigürasyonu
configure_usb_device() {
    echo
    print_status "USB Cihaz Konfigürasyonu"
    echo "========================"
    
    # Mevcut USB cihazları listele
    print_status "Bağlı USB cihazlar:"
    lsusb
    echo
    
    read -p "USB cihaz yolu (/dev/ttyACM0, /dev/ttyUSB0, auto): " device
    device=${device:-auto}
    
    read -p "Sürücü tipi (ft12cemi, tpuart, auto): " driver
    driver=${driver:-auto}
    
    # Konfigürasyon dosyasını güncelle
    sed -i "/^\[A\.usb\]/,/^$/ { 
        s/device = .*/device = $device/
        s/driver = .*/driver = $driver/
    }" "$CONFIG_FILE"
    
    print_success "USB cihaz konfigürasyonu güncellendi"
}

# Server konfigürasyonu
configure_server() {
    echo
    print_status "Server Konfigürasyonu"
    echo "====================="
    
    read -p "KNX adresi (1.1.128): " addr
    addr=${addr:-1.1.128}
    
    read -p "Client adres aralığı (1.1.129:8): " client_addrs
    client_addrs=${client_addrs:-1.1.129:8}
    
    # Konfigürasyon dosyasını güncelle
    sed -i "s/addr = .*/addr = $addr/" "$CONFIG_FILE"
    sed -i "s/client-addrs = .*/client-addrs = $client_addrs/" "$CONFIG_FILE"
    
    print_success "Server konfigürasyonu güncellendi"
}

# Debug konfigürasyonu
configure_debug() {
    echo
    print_status "Debug Konfigürasyonu"
    echo "===================="
    
    echo "Log seviyeleri: fatal, critical, error, warning, info, debug, trace"
    read -p "Log seviyesi (warning): " log_level
    log_level=${log_level:-warning}
    
    read -p "Trace mask (0): " trace_mask
    trace_mask=${trace_mask:-0}
    
    # Konfigürasyon dosyasını güncelle
    sed -i "s/error-level = .*/error-level = $log_level/" "$CONFIG_FILE"
    sed -i "s/trace-mask = .*/trace-mask = $trace_mask/" "$CONFIG_FILE"
    
    print_success "Debug konfigürasyonu güncellendi"
}

# knxd kaldır
uninstall_knxd() {
    check_root "uninstall"
    
    print_warning "knxd tamamen kaldırılacak!"
    read -p "Devam etmek istediğinizden emin misiniz? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "İşlem iptal edildi"
        return 0
    fi
    
    print_status "knxd kaldırılıyor..."
    
    # Servisi durdur ve devre dışı bırak
    systemctl stop knxd 2>/dev/null
    systemctl disable knxd 2>/dev/null
    
    # Dosyaları kaldır
    rm -f /usr/local/bin/knxd*
    rm -f /usr/local/lib/libknxd*
    rm -f "$SERVICE_FILE"
    rm -f "$CONFIG_FILE"
    rm -f "$LOG_FILE"
    
    # Kullanıcıyı kaldır
    userdel knxd 2>/dev/null
    
    systemctl daemon-reload
    
    print_success "knxd başarıyla kaldırıldı"
}

# Ana menü
show_menu() {
    clear
    echo "=================================="
    echo "   KNX USB Interface Yöneticisi   "
    echo "=================================="
    echo "1) knxd kurulum yap"
    echo "2) knxd başlat"
    echo "3) knxd durdur"
    echo "4) knxd yeniden başlat"
    echo "5) knxd durumunu göster"
    echo "6) knxd konfigürasyon"
    echo "7) knxd kaldır"
    echo "8) USB cihaz kontrolü"
    echo "0) Çıkış"
    echo "=================================="
}

# Ana program mantığı
main() {
    case "$1" in
        install)
            install_knxd
            ;;
        start)
            start_knxd
            ;;
        stop)
            stop_knxd
            ;;
        restart)
            restart_knxd
            ;;
        status)
            status_knxd
            ;;
        config)
            config_knxd
            ;;
        uninstall)
            uninstall_knxd
            ;;
        usb-check)
            check_usb_device
            ;;
        *)
            if [ $# -eq 0 ]; then
                # İnteraktif menü
                while true; do
                    show_menu
                    read -p "Seçiminizi yapın (0-8): " choice
                    
                    case $choice in
                        1) install_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        2) start_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        3) stop_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        4) restart_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        5) status_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        6) config_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        7) uninstall_knxd; read -p "Devam etmek için Enter'a basın..." ;;
                        8) check_usb_device; read -p "Devam etmek için Enter'a basın..." ;;
                        0) exit 0 ;;
                        *) print_error "Geçersiz seçim!" ;;
                    esac
                done
            else
                echo "Kullanım: $0 [install|start|stop|restart|status|config|uninstall|usb-check]"
                echo
                echo "Komutlar:"
                echo "  install    - knxd kurulumunu yap"
                echo "  start      - knxd servisini başlat"
                echo "  stop       - knxd servisini durdur"
                echo "  restart    - knxd servisini yeniden başlat"
                echo "  status     - knxd durumunu göster"
                echo "  config     - knxd konfigürasyonunu düzenle"
                echo "  uninstall  - knxd'yi tamamen kaldır"
                echo "  usb-check  - USB KNX cihazlarını kontrol et"
                echo
                echo "Parametre olmadan çalıştırırsanız interaktif menü açılır."
            fi
            ;;
    esac
}

# Ana fonksiyonu çalıştır
main "$@"