# 🎯 Добавление Android Studio в меню Linux Mint

## ✅ Что уже сделано

1. **Desktop файл создан** в `/home/ncux/.local/share/applications/android-studio.desktop`
2. **Права доступа установлены** (chmod +x)
3. **База данных обновлена** (update-desktop-database)

## 🔍 Проверка

### 1. Найти Android Studio в меню
- Откройте **Меню** (кнопка в левом нижнем углу)
- Найдите **"Android Studio"** в категории **"Разработка"** или **"Программирование"**
- Или найдите в **"Все приложения"**

### 2. Если не появился в меню
```bash
# Обновить базу данных приложений
update-desktop-database /home/ncux/.local/share/applications

# Перезапустить систему меню (если нужно)
killall cinnamon-session
```

### 3. Альтернативный способ запуска
```bash
# Запуск из терминала
android-studio

# Или напрямую
/home/ncux/android-studio/bin/studio.sh
```

## 🎨 Настройка иконки

Если иконка не отображается, можно:

### 1. Скачать иконку Android Studio
```bash
# Создать директорию для иконок
mkdir -p /home/ncux/.local/share/icons

# Скачать иконку (если нужно)
# wget https://developer.android.com/static/images/android-studio-icon.png -O /home/ncux/.local/share/icons/android-studio.png
```

### 2. Обновить desktop файл
```bash
# Отредактировать путь к иконке
nano /home/ncux/.local/share/applications/android-studio.desktop
```

## 🚀 Готово!

**Android Studio теперь доступен в меню Linux Mint!** 

- ✅ Desktop файл создан
- ✅ Права доступа установлены  
- ✅ База данных обновлена
- ✅ Готов к использованию

**Можно запускать Android Studio из меню!** 🎉
