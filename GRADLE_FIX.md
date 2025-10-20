# 🔧 Исправление проблемы с Gradle

## 🚨 Проблема
```
Project 'app' not found in root project 'android'
Unsupported class file major version 65
```

## ✅ Решение

### 1. Очистить все кэши
```bash
cd /home/ncux/Projects/glances_monitor

# Очистить Flutter кэш
flutter clean

# Очистить Gradle кэши
rm -rf android/.gradle
rm -rf ~/.gradle/caches

# Очистить build директории
rm -rf build/
rm -rf android/build/
```

### 2. Настроить Java для Flutter
```bash
# Flutter должен использовать Java из Android Studio
flutter config --jdk-dir="/home/ncux/android-studio/jbr"

# Проверить настройки
flutter doctor -v
```

### 3. Обновить Gradle конфигурацию

**android/gradle/wrapper/gradle-wrapper.properties:**
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```

**android/build.gradle:**
```gradle
buildscript {
    ext.kotlin_version = '1.8.20'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

### 4. Пересобрать проект
```bash
# Получить зависимости
flutter pub get

# Собрать debug APK
flutter build apk --debug

# Если успешно, собрать release APK
flutter build apk --release
```

## 🎯 Альтернативное решение

Если проблема не решается, создайте новый проект:

```bash
cd /home/ncux/Projects
flutter create glances_monitor_fixed
cd glances_monitor_fixed

# Скопировать код из старого проекта
cp -r ../glances_monitor/lib/* lib/
cp ../glances_monitor/pubspec.yaml .

# Обновить зависимости
flutter pub get

# Собрать APK
flutter build apk --debug
```

## 📱 Проверка результата

APK файлы будут в:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

## 🚀 Установка на устройство

```bash
# Установить на подключенное Android устройство
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**Приложение готово к использованию!** 🎉
