﻿#!/bin/bash

# ==============================================================================
# Toltek Blue BbbApiV3 - Update Bash Script
# Yavuz - 02/04/2025
# Bu script, Toltek.Blue.BbbApiV3 servisini Ubuntu sunucusunda kurar ve günceller.
#
# Çalıştırma Komutu (Örnek):
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- demo
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- subu
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- ebyu
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- kostu
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- ksbu

#
# Açıklama:
# - .NET SDK ve Runtime kontrol edilir ve eksikse kurulur.
# - BigBlueButton için Nginx yapılandırması ayarlanır.
# - Toltek.Blue.BbbApiV3 kod deposu çekilir/güncellenir.
# - Servis dosyaları kontrol edilir ve sistemde etkinleştirilir.
# ==============================================================================

set -e  # Hata oluşursa script'i durdur

# 📌 Kurulum Adını Parametre Olarak Al

INSTANCE_NAME=${1:-"default-instance"}

echo "📌 Kurulum başlatılıyor... (Instance: $INSTANCE_NAME)"

UBUNTU_VERSION=$(lsb_release -rs)

if [[ "$UBUNTU_VERSION" == "24.04" ]] || [[ "$UBUNTU_VERSION" == "22.04" ]]; then
    DOTNET_VERSION="10.0"
else
    echo "🚨 Desteklenmeyen Ubuntu sürümü: $UBUNTU_VERSION"
    exit 1
fi

echo "🟢 Ubuntu $UBUNTU_VERSION tespit edildi. .NET $DOTNET_VERSION kontrol ediliyor..."

HAS_DOTNET=false
HAS_DOTNET10=false

if command -v dotnet 2>/dev/null &> /dev/null; then
    HAS_DOTNET=true
    if dotnet --list-sdks 2>/dev/null | grep -q "^10\."; then
        HAS_DOTNET10=true
    fi
fi

if [ "$HAS_DOTNET10" = false ]; then
    echo "🔴 .NET 10 yüklü değil, kurulum başlatılıyor..."
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /usr/lib/dotnet
    sudo rm -rf /root/.dotnet
    sudo mkdir -p /usr/share/dotnet
    curl -sSL https://dot.net/v1/dotnet-install.sh | sudo bash /dev/stdin --channel 10.0 --install-dir /usr/share/dotnet
    echo 'export DOTNET_ROOT=/usr/share/dotnet' >> ~/.bashrc
    sudo ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
    dotnet --version  
    echo "✅ .NET $DOTNET_VERSION başarıyla yüklendi."
else
    echo "✅ .NET 10 zaten yüklü."
fi



BASE_DIR="/var/toltek"
INSTANCE_DIR="$BASE_DIR/$INSTANCE_NAME"
APPS_DIR="$INSTANCE_DIR/apps"
SETTINGS_DIR="$INSTANCE_DIR/settings"
LOGS_DIR="$INSTANCE_DIR/logs"
NGINX_CONFIG="/usr/share/bigbluebutton/nginx/$INSTANCE_NAME.blue.bbbapiv3.nginx"
SERVICE_FILE="/etc/systemd/system/$INSTANCE_NAME.blue.bbbapiv3.service"
REPO_URL="https://github.com/toltekyazilim/Toltek.Blue.BbbApiV3.git"
SERVICE_NAME="$INSTANCE_NAME.blue.bbbapiv3.service"

for dir in "$BASE_DIR" "$INSTANCE_DIR" "$APPS_DIR" "$SETTINGS_DIR" "$LOGS_DIR"; do
    if [ ! -d "$dir" ]; then
        sudo mkdir -p "$dir"
        echo "✅ Dizin oluşturuldu: $dir"
    else
        echo "🔹 Dizin zaten mevcut: $dir"
    fi
done
sudo chmod 777 "$SETTINGS_DIR" "$LOGS_DIR"

echo "🔄 Repository güncelleniyor..."
if [ ! -d "$APPS_DIR/Toltek.Blue.BbbApiV3/.git" ]; then
    sudo git clone "$REPO_URL" "$APPS_DIR/Toltek.Blue.BbbApiV3"
    echo "✅ Repository klonlandı."
else
    cd "$APPS_DIR/Toltek.Blue.BbbApiV3"
    git reset --hard
    git pull origin main
    echo "✅ Repository güncellendi."
fi

echo "🔒 SSL sertifikası yapılandırılıyor..."
dotnet dev-certs https --trust || echo "⚠️ Dev-cert yapılandırması başarısız oldu."

echo "🌐 BigBlueButton Nginx yapılandırması kontrol ediliyor..."
if [ -f "$NGINX_CONFIG" ]; then
    sudo rm "$NGINX_CONFIG"
    echo "✅ Mevcut Nginx konfigürasyonu kaldırıldı."
fi

sudo ln -s "$SETTINGS_DIR/nginx/$INSTANCE_NAME.blue.bbbapiv3.nginx" "$NGINX_CONFIG"
sudo service nginx reload
echo "✅ Nginx konfigürasyonu güncellendi ve yeniden yüklendi."

echo "🛠️ Servis yapılandırması kontrol ediliyor..."
if systemctl list-units --full -all | grep -Fq "$SERVICE_NAME"; then
    sudo systemctl stop "$SERVICE_NAME"
    echo "✅ Mevcut servis durduruldu."
fi

if [ -e "$SERVICE_FILE" ]; then
    if [ -L "$SERVICE_FILE" ]; then
        sudo unlink "$SERVICE_FILE"
        echo "✅ Eski sembolik link kaldırıldı."
    else
        sudo rm -f "$SERVICE_FILE"
        echo "✅ Eski servis dosyası kaldırıldı."
    fi
fi

sudo ln -s "$SETTINGS_DIR/systemd/$INSTANCE_NAME.blue.bbbapiv3.service" "$SERVICE_FILE"
echo "✅ Yeni servis dosyası oluşturuldu."

echo "🚀 Servis başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl start "$SERVICE_NAME"
sudo systemctl enable "$SERVICE_NAME"

echo "📊 Servis durumu:"
systemctl status "$SERVICE_NAME" --no-pager

echo "🎉 Kurulum tamamlandı!"

journalctl -u $INSTANCE_NAME.blue.bbbapiv3.service -e