#!/bin/bash

# EPUB Reader - Firebase Hosting Build & Deploy Script
# Bu script projeyi build edip Firebase'e deploy eder

set -e  # Hata durumunda durdur

echo "🚀 EPUB Reader Firebase Deploy Script"
echo "======================================"
echo ""

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Flutter yüklü mü kontrol et
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter bulunamadı. Lütfen Flutter'ı yükleyin.${NC}"
    echo "https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo -e "${GREEN}✅ Flutter bulundu: $(flutter --version | head -n 1)${NC}"
echo ""

# Firebase CLI yüklü mü kontrol et
if ! command -v firebase &> /dev/null; then
    echo -e "${YELLOW}⚠️  Firebase CLI bulunamadı. Yükleniyor...${NC}"
    npm install -g firebase-tools
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Firebase CLI yüklenemedi. Lütfen manuel yükleyin:${NC}"
        echo "npm install -g firebase-tools"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Firebase CLI bulundu${NC}"
echo ""

# Dependencies'leri güncelle
echo "📦 Dependencies yükleniyor..."
flutter pub get
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Dependencies yüklenemedi${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Dependencies yüklendi${NC}"
echo ""

# Flutter web build
echo "🔨 Flutter web build başlatılıyor..."
echo "Bu işlem birkaç dakika sürebilir..."
flutter build web --release --web-renderer canvaskit
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build başarısız${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Build tamamlandı${NC}"
echo ""

# Build boyutunu göster
BUILD_SIZE=$(du -sh build/web | cut -f1)
echo "📊 Build boyutu: $BUILD_SIZE"
echo ""

# Firebase'e deploy
echo "🌐 Firebase'e deploy ediliyor..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Deploy başarılı!${NC}"
    echo ""
    echo "🎉 Uygulamanız şu adreste yayında:"
    firebase hosting:channel:list | grep "live" | awk '{print $4}'
else
    echo -e "${RED}❌ Deploy başarısız${NC}"
    exit 1
fi
