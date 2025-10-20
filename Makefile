# Makefile для Glances Monitor
# Упрощает процесс сборки и развертывания

.PHONY: help clean build debug release version update-version install-deps test

# Цвета для вывода
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

# Переменные
VERSION ?= 1.0.0
BUILD_NUMBER ?= 1
RELEASE_DIR = releases

help: ## Показать справку
	@echo "$(BLUE)Glances Monitor - Доступные команды:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

clean: ## Очистить проект
	@echo "$(BLUE)Очистка проекта...$(NC)"
	flutter clean
	flutter pub get

install-deps: ## Установить зависимости
	@echo "$(BLUE)Установка зависимостей...$(NC)"
	flutter pub get

update-version: ## Обновить версию и информацию о сборке
	@echo "$(BLUE)Обновление версии...$(NC)"
	@if command -v dart >/dev/null 2>&1; then \
		dart scripts/update_version.dart; \
		echo "$(GREEN)Версия обновлена$(NC)"; \
	else \
		echo "$(YELLOW)Dart не найден. Пропускаем обновление версии.$(NC)"; \
	fi

version: update-version ## Показать текущую версию
	@echo "$(BLUE)Текущая версия:$(NC)"
	@if [ -f "lib/utils/build_info_data.dart" ]; then \
		grep "version = " lib/utils/build_info_data.dart | sed 's/.*version = '\''\(.*\)'\'';.*/\1/'; \
		grep "buildNumber = " lib/utils/build_info_data.dart | sed 's/.*buildNumber = '\''\(.*\)'\'';.*/\1/'; \
		grep "commitHash = " lib/utils/build_info_data.dart | sed 's/.*commitHash = '\''\(.*\)'\'';.*/\1/'; \
	else \
		echo "Информация о версии недоступна"; \
	fi

debug: clean install-deps ## Собрать debug APK
	@echo "$(BLUE)Сборка debug APK...$(NC)"
	flutter build apk --debug --build-name=$(VERSION) --build-number=$(BUILD_NUMBER)
	@echo "$(GREEN)Debug APK собран$(NC)"

release: clean install-deps update-version ## Собрать release APK
	@echo "$(BLUE)Сборка release APK...$(NC)"
	flutter build apk --release --build-name=$(VERSION) --build-number=$(BUILD_NUMBER)
	@echo "$(GREEN)Release APK собран$(NC)"

build: release ## Собрать все APK (debug + release)
	@echo "$(BLUE)Сборка всех APK...$(NC)"
	flutter build apk --debug --build-name=$(VERSION) --build-number=$(BUILD_NUMBER)
	@echo "$(GREEN)Все APK собраны$(NC)"

package: build ## Создать пакет с APK файлами
	@echo "$(BLUE)Создание пакета...$(NC)"
	@mkdir -p $(RELEASE_DIR)
	@cp build/app/outputs/flutter-apk/app-debug.apk $(RELEASE_DIR)/glances_monitor_debug_v$(VERSION)_b$(BUILD_NUMBER).apk
	@cp build/app/outputs/flutter-apk/app-release.apk $(RELEASE_DIR)/glances_monitor_release_v$(VERSION)_b$(BUILD_NUMBER).apk
	@echo "$(GREEN)Пакет создан в директории $(RELEASE_DIR)$(NC)"

test: ## Запустить тесты
	@echo "$(BLUE)Запуск тестов...$(NC)"
	flutter test

analyze: ## Анализ кода
	@echo "$(BLUE)Анализ кода...$(NC)"
	flutter analyze

format: ## Форматирование кода
	@echo "$(BLUE)Форматирование кода...$(NC)"
	dart format .

# Команды для разработки
dev: clean install-deps ## Настройка для разработки
	@echo "$(GREEN)Проект готов для разработки$(NC)"

# Команды для релиза
release-package: clean install-deps update-version build package ## Полный цикл сборки релиза
	@echo "$(GREEN)Релиз готов!$(NC)"
	@echo "$(BLUE)Файлы:$(NC)"
	@ls -la $(RELEASE_DIR)/glances_monitor_*_v$(VERSION)_b$(BUILD_NUMBER).apk 2>/dev/null || echo "Файлы не найдены"

# Показать информацию о проекте
info: ## Показать информацию о проекте
	@echo "$(BLUE)Информация о проекте:$(NC)"
	@echo "  Название: Glances Monitor"
	@echo "  Версия: $(VERSION)"
	@echo "  Сборка: $(BUILD_NUMBER)"
	@echo "  Flutter: $$(flutter --version | head -n1)"
	@echo "  Dart: $$(dart --version 2>/dev/null || echo 'Не установлен')"
	@echo "  Git: $$(git --version 2>/dev/null || echo 'Не установлен')"
