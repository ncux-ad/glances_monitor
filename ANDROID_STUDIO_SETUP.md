# 🚀 Настройка Android Studio для Flutter

## ✅ Что уже сделано

1. **Android Studio установлен** в `/home/ncux/android-studio/`
2. **Символическая ссылка создана** для запуска из терминала
3. **PATH настроен** для доступа к команде `android-studio`

## 🔧 Первоначальная настройка Android Studio

### 1. Запуск Android Studio
```bash
# Запуск из терминала
android-studio

# Или напрямую
/home/ncux/android-studio/bin/studio.sh
```

### 2. Настройка при первом запуске

#### Шаг 1: Welcome Screen
- Выберите **"More Actions"** → **"Customize"** → **"All settings"**

#### Шаг 2: SDK Manager
- Перейдите в **"Appearance & Behavior"** → **"System Settings"** → **"Android SDK"**
- Убедитесь, что установлены:
  - ✅ **Android SDK Platform 33**
  - ✅ **Android SDK Build-Tools 33.0.0**
  - ✅ **Android SDK Platform-Tools**
  - ✅ **Android SDK Command-line Tools (latest)**

#### Шаг 3: Flutter Plugin
- Перейдите в **"Plugins"**
- Найдите и установите **"Flutter"** (включает Dart plugin)
- Перезапустите Android Studio

#### Шаг 4: Flutter SDK Path
- Перейдите в **"Languages & Frameworks"** → **"Flutter"**
- Укажите путь к Flutter SDK: `/home/ncux/Projects/glances_monitor` (или где установлен Flutter)
- Нажмите **"Apply"**

## 🎯 Настройка для Flutter проекта

### 1. Открыть проект
```bash
cd /home/ncux/Projects/glances_monitor
android-studio .
```

### 2. Настроить Android SDK в проекте
- В Android Studio: **"File"** → **"Project Structure"**
- Убедитесь, что **"Android SDK location"** указывает на `/home/ncux/Android/Sdk`

### 3. Синхронизация Gradle
- Android Studio автоматически предложит синхронизацию
- Нажмите **"Sync Now"**

## 🔧 Альтернативная настройка через терминал

Если Android Studio не открывается, настройте SDK вручную:

```bash
# Установить переменные окружения
export ANDROID_HOME=$HOME/Android/Sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Принять лицензии
flutter doctor --android-licenses

# Проверить настройку
flutter doctor
```

## 📱 Создание эмулятора (опционально)

### 1. AVD Manager
- В Android Studio: **"Tools"** → **"AVD Manager"**
- Нажмите **"Create Virtual Device"**

### 2. Выбор устройства
- Выберите **"Phone"** → **"Pixel 7"** (или любой другой)
- Нажмите **"Next"**

### 3. Выбор системы
- Выберите **"API 33"** (Android 13)
- Нажмите **"Next"** → **"Finish"**

### 4. Запуск эмулятора
- Нажмите **"Play"** рядом с созданным эмулятором

## 🚀 Сборка Flutter приложения

### 1. Через Android Studio
- Откройте проект в Android Studio
- Выберите **"Run"** → **"Run 'main.dart'"**
- Выберите устройство (эмулятор или подключенный телефон)

### 2. Через терминал
```bash
cd /home/ncux/Projects/glances_monitor

# Debug сборка
flutter build apk --debug

# Release сборка
flutter build apk --release

# Запуск на устройстве
flutter run
```

## 🔍 Проверка готовности

```bash
# Проверить Flutter
flutter doctor

# Проверить Android SDK
echo $ANDROID_HOME
echo $JAVA_HOME

# Проверить доступность команд
which flutter
which adb
```

## 🎉 Готово!

После настройки Android Studio вы сможете:
- ✅ Открывать Flutter проекты в IDE
- ✅ Запускать приложения на эмуляторе
- ✅ Отлаживать код
- ✅ Собирать APK файлы
- ✅ Использовать все возможности Android Studio

**Приложение готово к разработке!** 🚀
