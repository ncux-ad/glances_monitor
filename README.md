# Glances Monitor - Flutter приложение для мониторинга серверов

Приложение для мониторинга системных ресурсов серверов через API Glances.

## 🚀 Возможности

- **Мониторинг в реальном времени** CPU, памяти, диска, сети
- **Множественные серверы** - добавление и управление несколькими серверами
- **Безопасная аутентификация** - поддержка Basic Auth
- **Современный UI** - красивый и интуитивный интерфейс
- **Кроссплатформенность** - работает на Android и iOS

## 📱 Установка

### Требования
- Flutter SDK 3.0+
- Android Studio / Xcode
- Glances сервер на удаленных машинах

### Сборка
```bash
# Клонирование репозитория
git clone <repository-url>
cd glances_monitor_new

# Установка зависимостей
flutter pub get

# Настройка Android (создайте local.properties из шаблона)
cp android/local.properties.template android/local.properties
# Отредактируйте пути к SDK в local.properties

# Сборка для Android
flutter build apk --release

# Сборка для iOS
flutter build ios --release
```

## 🔧 Настройка серверов

### Добавление сервера
1. **Добавление сервера:**
   - Нажмите кнопку "+" на главном экране
   - Заполните форму с данными сервера
   - Используйте "Тест подключения" для проверки
   - Сохраните сервер

2. **Примеры серверов:**
   ```
   Example Server 1:
   - URL: http://your-server-ip:61209
   - Username: your-username
   - Password: your-password
   - Flag: 🇺🇸

   Example Server 2:
   - URL: http://another-server-ip:61209
   - Username: another-username
   - Password: another-password
   - Flag: 🇪🇺
   ```

## 📊 Мониторинг метрик

### CPU
- Процент загрузки
- Информация о ядрах
- Температура (если доступна)

### Память
- Использование RAM
- Использование swap
- Детальная информация о процессах

### Диск
- Использование дискового пространства
- Скорость чтения/записи
- Информация о файловых системах

### Сеть
- Входящий/исходящий трафик
- Статистика по интерфейсам
- Активные соединения

## 🛡️ Безопасность

### Важные моменты:
- **Никогда не коммитьте** файл `android/local.properties`
- **Используйте переменные окружения** для хранения секретов
- **Проверяйте .gitignore** перед каждым коммитом
- **См. SECURITY.md** для подробной информации

### Настройка Glances сервера
```bash
# Установка Glances
pip install glances

# Запуск с API
glances -w --bind 0.0.0.0 --port 61209

# С настройкой аутентификации (рекомендуется)
glances -w --bind 0.0.0.0 --port 61209 --username your-username --password your-secure-password
```

## 🏗️ Архитектура

### Структура проекта
```
lib/
├── main.dart                 # Точка входа
├── models/                   # Модели данных
│   ├── server_config.dart    # Конфигурация сервера
│   └── system_metrics.dart   # Системные метрики
├── screens/                  # Экраны приложения
│   ├── home_screen.dart      # Главный экран
│   ├── add_server_screen.dart # Добавление сервера
│   └── server_detail_screen.dart # Детали сервера
├── services/                 # Сервисы
│   ├── glances_api_service.dart # API Glances
│   └── storage_service.dart  # Локальное хранилище
└── widgets/                  # Переиспользуемые виджеты
    ├── metric_card.dart      # Карточка метрики
    └── server_list_tile.dart # Элемент списка серверов
```

### Технологии
- **Flutter** - кроссплатформенная разработка
- **Dio** - HTTP клиент для API запросов
- **Shared Preferences** - локальное хранилище настроек
- **Provider** - управление состоянием

## 📈 Разработка

### Запуск в режиме разработки
```bash
# Запуск на Android
flutter run

# Запуск на iOS
flutter run -d ios

# Запуск в веб-браузере
flutter run -d chrome
```

### Тестирование
```bash
# Запуск тестов
flutter test

# Проверка кода
flutter analyze
```

## 🤝 Вклад в проект

1. Форкните репозиторий
2. Создайте ветку для новой функции
3. Внесите изменения
4. Добавьте тесты
5. Создайте Pull Request

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл LICENSE для подробностей.

## 🔗 Полезные ссылки

- [Glances документация](https://glances.readthedocs.io/)
- [Flutter документация](https://docs.flutter.dev/)
- [Dio HTTP клиент](https://pub.dev/packages/dio)

## 📞 Поддержка

При возникновении проблем создайте issue в репозитории или свяжитесь с командой разработки.

---

**⚠️ Важно:** Всегда используйте безопасные пароли и не коммитьте секреты в репозиторий!
