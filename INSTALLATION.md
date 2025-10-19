# Инструкции по установке и сборке

## 🚀 Быстрый старт

### 1. Установка Flutter (уже установлен ✅)
```bash
# Flutter уже установлен и работает
flutter --version
```

### 2. Установка Android SDK

#### Вариант A: Через Android Studio (рекомендуется)
```bash
# Скачать Android Studio
wget https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2023.3.1.18/android-studio-2023.3.1.18-linux.tar.gz
tar -xzf android-studio-2023.3.1.18-linux.tar.gz
sudo mv android-studio /opt/
sudo ln -s /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio

# Запустить Android Studio и установить SDK
android-studio
```

#### Вариант B: Только Android SDK (быстрее)
```bash
# Создать директорию для Android SDK
mkdir -p ~/Android/Sdk

# Скачать command line tools
cd ~/Android/Sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools tools

# Настроить переменные окружения
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
source ~/.bashrc

# Установить SDK компоненты
sdkmanager --update
sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0"
```

### 3. Настройка Flutter
```bash
# Принять лицензии Android
flutter doctor --android-licenses

# Проверить установку
flutter doctor
```

### 4. Сборка приложения
```bash
cd /home/ncux/Projects/glances_monitor

# Debug сборка (быстрее)
flutter build apk --debug

# Release сборка (оптимизированная)
flutter build apk --release
```

## 📱 Тестирование

### На эмуляторе
```bash
# Создать эмулятор
flutter emulators --create

# Запустить эмулятор
flutter emulators --launch <emulator_id>

# Запустить приложение
flutter run
```

### На реальном устройстве
```bash
# Подключить Android устройство по USB
# Включить отладку по USB в настройках устройства

# Запустить приложение
flutter run
```

## 🔧 Альтернативные способы сборки

### Через Docker (если есть проблемы с SDK)
```bash
# Создать Dockerfile для Flutter
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    openjdk-11-jdk

# Установить Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

# Установить Android SDK
RUN mkdir -p /android-sdk
ENV ANDROID_HOME=/android-sdk
ENV PATH="${ANDROID_HOME}/tools/bin:${PATH}"

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build apk --release

CMD ["ls", "-la", "build/app/outputs/flutter-apk/"]
EOF

# Собрать через Docker
docker build -t glances-monitor .
docker run -v $(pwd)/build:/app/build glances-monitor
```

## 📋 Проверка готовности

### Все должно работать если:
```bash
# 1. Flutter установлен
flutter --version

# 2. Android SDK настроен
echo $ANDROID_HOME

# 3. Лицензии приняты
flutter doctor

# 4. Проект компилируется
flutter analyze
```

## 🚨 Решение проблем

### Ошибка "No Android SDK found"
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

### Ошибка лицензий
```bash
flutter doctor --android-licenses
# Нажать 'y' для всех лицензий
```

### Ошибка компиляции
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## 📦 Готовый APK

После успешной сборки APK будет в:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

Установка на устройство:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```
