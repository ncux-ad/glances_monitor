#!/bin/bash

# Скрипт для сборки версионированных APK
# Использование: ./scripts/build_release.sh [version] [build_number]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка аргументов
VERSION=${1:-"1.0.0"}
BUILD_NUMBER=${2:-"1"}

print_message "Сборка APK версии $VERSION (сборка $BUILD_NUMBER)"

# Проверка наличия Flutter
if ! command -v flutter &> /dev/null; then
    print_error "Flutter не найден. Установите Flutter и добавьте в PATH."
    exit 1
fi

# Проверка наличия git
if ! command -v git &> /dev/null; then
    print_warning "Git не найден. Информация о коммите будет недоступна."
fi

# Обновление версии
print_message "Обновление версии..."
if command -v dart &> /dev/null; then
    dart scripts/update_version.dart
    print_success "Версия обновлена"
else
    print_warning "Dart не найден. Пропускаем обновление версии."
fi

# Очистка предыдущих сборок
print_message "Очистка предыдущих сборок..."
flutter clean
flutter pub get

# Проверка зависимостей
print_message "Проверка зависимостей..."
flutter pub deps

# Сборка APK для отладки
print_message "Сборка debug APK..."
flutter build apk --debug --build-name=$VERSION --build-number=$BUILD_NUMBER

# Сборка APK для релиза
print_message "Сборка release APK..."
flutter build apk --release --build-name=$VERSION --build-number=$BUILD_NUMBER

# Создание директории для релизов
RELEASE_DIR="releases"
mkdir -p $RELEASE_DIR

# Копирование APK файлов
print_message "Копирование APK файлов..."
cp build/app/outputs/flutter-apk/app-debug.apk $RELEASE_DIR/glances_monitor_debug_v${VERSION}_b${BUILD_NUMBER}.apk
cp build/app/outputs/flutter-apk/app-release.apk $RELEASE_DIR/glances_monitor_release_v${VERSION}_b${BUILD_NUMBER}.apk

# Создание информации о сборке
print_message "Создание информации о сборке..."
cat > $RELEASE_DIR/build_info_v${VERSION}_b${BUILD_NUMBER}.txt << EOF
Glances Monitor - Информация о сборке
=====================================

Версия: $VERSION
Номер сборки: $BUILD_NUMBER
Дата сборки: $(date '+%Y-%m-%d %H:%M:%S')

Git информация:
$(git log -1 --pretty=format:"Коммит: %H%nАвтор: %an <%ae>%nДата: %ad%nСообщение: %s" 2>/dev/null || echo "Git информация недоступна")

Файлы:
- glances_monitor_debug_v${VERSION}_b${BUILD_NUMBER}.apk (Debug)
- glances_monitor_release_v${VERSION}_b${BUILD_NUMBER}.apk (Release)

Размеры файлов:
$(ls -lh $RELEASE_DIR/glances_monitor_*_v${VERSION}_b${BUILD_NUMBER}.apk 2>/dev/null || echo "Файлы не найдены")
EOF

print_success "Сборка завершена успешно!"
print_message "Файлы сохранены в директории: $RELEASE_DIR"
print_message "Debug APK: glances_monitor_debug_v${VERSION}_b${BUILD_NUMBER}.apk"
print_message "Release APK: glances_monitor_release_v${VERSION}_b${BUILD_NUMBER}.apk"
print_message "Информация о сборке: build_info_v${VERSION}_b${BUILD_NUMBER}.txt"

# Показать размеры файлов
if [ -d "$RELEASE_DIR" ]; then
    print_message "Размеры файлов:"
    ls -lh $RELEASE_DIR/glances_monitor_*_v${VERSION}_b${BUILD_NUMBER}.apk 2>/dev/null || true
fi
