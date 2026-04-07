﻿#!/bin/bash

# ==============================================================================
# Toltek Blue BbbApiV3 - Update Bash Script
# Yavuz - 02/04/2025
# Bu script, Toltek.Blue.BbbApiV3 servisini Ubuntu sunucusunda kurar ve günceller.
#
# Çalıştırma Komutu (Örnek):
# wget -qO- https://raw.githubusercontent.com/toltekyazilim/Toltek.Blue.BbbApiV3/refs/heads/main/bash/install.sh | bash -s -- ebyu

#
# Açıklama:
# - .NET SDK ve Runtime kontrol edilir ve eksikse kurulur.
# - BigBlueButton için Nginx yapılandırması ayarlanır.
# - Toltek.Blue.BbbApiV3 kod deposu çekilir/güncellenir.
# - Servis dosyaları kontrol edilir ve sistemde etkinleştirilir.
# ==============================================================================

set -e  # Hata oluşursa script'i durdur

# 📌 Kurulum Adını Parametre Olarak Al

 

echo "📌 Kurulum başlatılıyor... (Instance: ebyu"

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

for dir in "/var/toltek" "/var/toltek/ebyu" "/var/toltek/ebyu/apps" "/var/toltek/ebyu/settings" "/var/toltek/ebyu/logs"; do
    if [ ! -d "$dir" ]; then
        sudo mkdir -p "$dir"
        echo "✅ Dizin oluşturuldu: $dir"
    else
        echo "🔹 Dizin zaten mevcut: $dir"
    fi
done
sudo chmod 777 "/var/toltek/ebyu/settings" "/var/toltek/ebyu/logs"

echo "🔄 Repository güncelleniyor..."
if [ ! -d "/var/toltek/ebyu/apps/Toltek.Blue.BbbApiV3/.git" ]; then
    sudo git clone "https://github.com/toltekyazilim/Toltek.Blue.BbbApiV3.git" "/var/toltek/ebyu/apps/Toltek.Blue.BbbApiV3"
    echo "✅ Repository klonlandı."
else
    cd "/var/toltek/ebyu/apps/Toltek.Blue.BbbApiV3"
    git reset --hard
    git pull origin main
    echo "✅ Repository güncellendi."
fi

#echo "🔒 SSL sertifikası yapılandırılıyor..."
#dotnet dev-certs https --trust || echo "⚠️ Dev-cert yapılandırması başarısız oldu."

echo "🌐 BigBlueButton Nginx yapılandırması kontrol ediliyor..."
if [ -f "/usr/share/bigbluebutton/nginx/ebyu.blue.bbbapiv3.nginx" ]; then
    sudo rm "/usr/share/bigbluebutton/nginx/ebyu.blue.bbbapiv3.nginx"
    echo "✅ Mevcut Nginx konfigürasyonu kaldırıldı."
fi

sudo ln -s "/var/toltek/ebyu/settings/nginx/ebyu.blue.bbbapiv3.nginx" "/usr/share/bigbluebutton/nginx/ebyu.blue.bbbapiv3.nginx"
sudo service nginx reload
echo "✅ Nginx konfigürasyonu güncellendi ve yeniden yüklendi."

echo "🛠️ Servis yapılandırması kontrol ediliyor..."
if systemctl list-units --full -all | grep -Fq "ebyu.blue.bbbapiv3.service"; then
    sudo systemctl stop "ebyu.blue.bbbapiv3.service"
    echo "✅ Mevcut servis durduruldu."
fi

if [ -e "/etc/systemd/system/ebyu.blue.bbbapiv3.service" ]; then
    if [ -L "/etc/systemd/system/ebyu.blue.bbbapiv3.service" ]; then
        sudo unlink "/etc/systemd/system/ebyu.blue.bbbapiv3.service"
        echo "✅ Eski sembolik link kaldırıldı."
    else
        sudo rm -f "/etc/systemd/system/ebyu.blue.bbbapiv3.service"
        echo "✅ Eski servis dosyası kaldırıldı."
    fi
fi

sudo ln -s "/var/toltek/ebyu/settings/systemd/ebyu.blue.bbbapiv3.service" "/etc/systemd/system/ebyu.blue.bbbapiv3.service"
echo "✅ Yeni servis dosyası oluşturuldu."

echo "🚀 Servis başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl start "ebyu.blue.bbbapiv3.service"
sudo systemctl enable "ebyu.blue.bbbapiv3.service"

echo "📊 Servis durumu:"
systemctl status "ebyu.blue.bbbapiv3.service" --no-pager

echo "🎉 Kurulum tamamlandı!"

journalctl -u ebyu.blue.bbbapiv3.service -e