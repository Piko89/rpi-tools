#!/bin/bash
# =====================================================
# Raspberry Pi Zero 2 W - Oh My Posh Installer & Remover
# Author: ChatGPT (for Piko Kek)
# =====================================================

POSH_BIN="/usr/local/bin/oh-my-posh"
THEME_DIR="$HOME/.poshthemes"
BASHRC="$HOME/.bashrc"
THEME_NAME="paradox.omp.json"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "armv7l" ]]; then
    POSH_URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-arm"
elif [[ "$ARCH" == "aarch64" ]]; then
    POSH_URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-arm64"
else
    echo "❌ Bu mimari desteklenmiyor: $ARCH"
    exit 1
fi

# Uninstall mode
if [[ "$1" == "--uninstall" ]]; then
    echo "🧹 Oh My Posh kaldırılıyor..."

    # Remove binary
    if [[ -f "$POSH_BIN" ]]; then
        sudo rm -f "$POSH_BIN"
        echo "🗑️  Binary kaldırıldı."
    fi

    # Remove theme dir
    if [[ -d "$THEME_DIR" ]]; then
        rm -rf "$THEME_DIR"
        echo "🗑️  Tema dosyaları silindi."
    fi

    # Clean .bashrc
    sed -i '/oh-my-posh init bash/d' "$BASHRC"
    echo "🧾 .bashrc temizlendi."

    echo "✅ Kaldırma tamamlandı. Değişikliklerin aktif olması için yeni terminal aç veya 'source ~/.bashrc' komutunu çalıştır."
    exit 0
fi

echo "🚀 Raspberry Pi Zero 2 için Oh My Posh kurulumu başlatılıyor..."
sudo apt update
sudo apt install -y wget unzip

# Download binary
echo "📦 Oh My Posh indiriliyor..."
wget -q "$POSH_URL" -O oh-my-posh
sudo mv oh-my-posh "$POSH_BIN"
sudo chmod +x "$POSH_BIN"

# Download themes
echo "🎨 Tema dosyaları indiriliyor..."
mkdir -p "$THEME_DIR"
wget -q https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O "$THEME_DIR/themes.zip"
unzip -q "$THEME_DIR/themes.zip" -d "$THEME_DIR"
chmod u+rw "$THEME_DIR"/*.omp.*
rm "$THEME_DIR/themes.zip"

# Update bashrc
if ! grep -q "oh-my-posh init bash" "$BASHRC"; then
    echo "eval \"\$(oh-my-posh init bash --config $THEME_DIR/$THEME_NAME)\"" >> "$BASHRC"
    echo "🧩 .bashrc güncellendi."
else
    echo "⚠️  .bashrc zaten oh-my-posh satırı içeriyor, tekrar eklenmedi."
fi

echo "✅ Kurulum tamamlandı! Yeni terminal aç veya şu komutu çalıştır:"
echo "   source ~/.bashrc"
echo ""
echo "💡 Kaldırmak için: ./ohmyposh-setup.sh --uninstall"
