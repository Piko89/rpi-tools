#!/bin/bash

# Wi-Fi yönetim scripti - NMCLI tabanlı
# Çalıştırmak için: sudo bash wifi-manager.sh

while true; do
    echo "========================================"
    echo "   Raspberry Pi Wi-Fi Yönetim Scripti  "
    echo "========================================"
    echo "1) Etraftaki Wi-Fi ağlarını listele ve bağlan"
    echo "2) Kayıtlı Wi-Fi ağlarını listele ve bağlan"
    echo "3) Oppo ağına bağlan"
    echo "4) Çıkış"
    echo "----------------------------------------"
    read -p "Seçiminiz [1-4]: " choice

    case $choice in
        1)
            echo ""
            echo "Etraftaki Wi-Fi ağları taranıyor..."
            nmcli device wifi rescan
            nmcli device wifi list
            echo ""
            read -p "Bağlanmak istediğiniz SSID'i girin: " ssid
            read -sp "Şifreyi girin: " password
            echo ""
            echo "Bağlanılıyor..."
            sudo nmcli device wifi connect "$ssid" password "$password"
            read -p "Devam etmek için Enter'a basın..."
            ;;
        2)
            echo ""
            echo "Kayıtlı Wi-Fi ağları:"
            nmcli connection show | awk '/wifi/ {print NR-1 ") "$1}'
            echo ""
            read -p "Bağlanmak istediğiniz ağın adını girin: " saved_ssid
            echo "Bağlanılıyor..."
            sudo nmcli connection up "$saved_ssid"
            read -p "Devam etmek için Enter'a basın..."
            ;;
        3)
            echo ""
            echo "Oppo ağına bağlanılıyor..."
            sudo nmcli connection up "Oppo"
            read -p "Devam etmek için Enter'a basın..."
            ;;
        4)
            echo "Çıkılıyor..."
            exit 0
            ;;
        *)
            echo "Geçersiz seçim! Tekrar deneyin."
            read -p "Devam etmek için Enter'a basın..."
            ;;
    esac
done
