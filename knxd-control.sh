#!/bin/bash

# KNXD kontrol scripti - socket uyumlu ve ETS bilgili

# ETS bağlantı bilgileri (LAN IP ve port)
ETS_IP=$(hostname -I | awk '{print $1}')
ETS_PORT=3671

while true; do
    echo "===================================="
    echo "        KNX kontrol menüsü           "
    echo "===================================="
    echo "1) KNX aç"
    echo "2) KNX kapa"
    echo "3) KNX durumu"
    echo "4) Çıkış"
    read -p "Seçiminiz (1-4): " secim

    case $secim in
        1)
            echo "KNX servisi ve socket başlatılıyor..."
            sudo systemctl enable knxd.socket
            sudo systemctl enable knxd.service
            sudo systemctl start knxd.socket
            sudo systemctl start knxd.service
            sleep 1
            sudo systemctl status knxd.service --no-pager
            ;;
        2)
            echo "KNX servisi ve socket durduruluyor..."
            sudo systemctl stop knxd.service
            sudo systemctl stop knxd.socket
            sudo systemctl disable knxd.service
            sudo systemctl disable knxd.socket
            sleep 1
            sudo systemctl status knxd.service --no-pager
            ;;
        3)
            echo "------------------------------------"
            echo "KNX Servis Durumu:"
            systemctl status knxd.service --no-pager
            echo ""
            echo "KNX Socket Durumu:"
            systemctl status knxd.socket --no-pager
            echo ""
            echo "ETS Bağlantı Bilgileri:"
            echo "IP: $ETS_IP"
            echo "Port: $ETS_PORT"
            echo "------------------------------------"
            ;;
        4)
            echo "Çıkılıyor..."
            exit 0
            ;;
        *)
            echo "Geçersiz seçim. Tekrar deneyin."
            ;;
    esac
    echo ""
done
