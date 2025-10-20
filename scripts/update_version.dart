#!/usr/bin/env dart

import 'dart:io';

/// Скрипт для обновления версии и получения информации о сборке
void main(List<String> args) async {
  print('🔄 Обновление версии приложения...');
  
  // Проверяем статус git
  final gitStatus = await _checkGitStatus();
  if (gitStatus['hasUncommittedChanges'] == true) {
    print('⚠️  ВНИМАНИЕ: Есть незакоммиченные изменения!');
    print('   Рекомендуется сначала закоммитить изменения:');
    print('   git add .');
    print('   git commit -m "описание изменений"');
    print('   Затем запустить: make update-version');
    print('');
    print('   Или продолжить с текущими изменениями? (y/N)');
    // В реальном приложении здесь был бы ввод пользователя
    print('   Продолжаем с текущими изменениями...');
  }
  
  // Получаем информацию о git
  final gitInfo = await _getGitInfo();
  
  // Обновляем pubspec.yaml
  await _updatePubspec(gitInfo);
  
  // Создаем файл с информацией о сборке
  await _createBuildInfoFile(gitInfo);
  
  print('✅ Версия обновлена успешно!');
  print('📊 Информация о сборке:');
  print('   Версия: ${gitInfo['version']}');
  print('   Сборка: ${gitInfo['buildNumber']}');
  print('   Коммит: ${gitInfo['commitHash']}');
  print('   Дата: ${gitInfo['buildDate']}');
  print('');
  print('📝 Следующие шаги:');
  print('   1. Проверьте изменения: git status');
  print('   2. Добавьте файлы: git add lib/utils/build_info_data.dart pubspec.yaml');
  print('   3. Закоммитьте: git commit -m "chore: обновление версии"');
  print('   4. Соберите: make build');
}

/// Проверить статус git
Future<Map<String, dynamic>> _checkGitStatus() async {
  try {
    final statusResult = await Process.run('git', ['status', '--porcelain']);
    final hasUncommittedChanges = statusResult.stdout.toString().trim().isNotEmpty;
    
    return {
      'hasUncommittedChanges': hasUncommittedChanges,
      'statusOutput': statusResult.stdout.toString().trim(),
    };
  } catch (e) {
    return {
      'hasUncommittedChanges': false,
      'statusOutput': '',
    };
  }
}

/// Получить информацию о git
Future<Map<String, String>> _getGitInfo() async {
  try {
    // Получаем хеш коммита
    final commitResult = await Process.run('git', ['rev-parse', 'HEAD']);
    final commitHash = commitResult.stdout.toString().trim();
    
    // Получаем короткий хеш
    final shortHash = commitHash.length > 7 ? commitHash.substring(0, 7) : commitHash;
    
    // Получаем количество коммитов
    final countResult = await Process.run('git', ['rev-list', '--count', 'HEAD']);
    final buildNumber = countResult.stdout.toString().trim();
    
    // Получаем дату последнего коммита
    final dateResult = await Process.run('git', ['log', '-1', '--format=%ci']);
    final commitDate = dateResult.stdout.toString().trim();
    
    // Парсим дату
    final date = DateTime.parse(commitDate.split(' ')[0]);
    final buildDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // Определяем версию на основе тегов
    final tagResult = await Process.run('git', ['describe', '--tags', '--abbrev=0']);
    String version = '1.0.0';
    if (tagResult.exitCode == 0) {
      final tag = tagResult.stdout.toString().trim();
      if (tag.startsWith('v')) {
        version = tag.substring(1);
      } else {
        version = tag;
      }
    }
    
    return {
      'version': version,
      'buildNumber': buildNumber,
      'commitHash': shortHash,
      'buildDate': buildDate,
      'fullCommitHash': commitHash,
    };
  } catch (e) {
    print('⚠️ Ошибка получения git информации: $e');
    return {
      'version': '1.0.0',
      'buildNumber': '1',
      'commitHash': 'dev-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      'buildDate': DateTime.now().toIso8601String().split('T')[0],
      'fullCommitHash': 'dev-${DateTime.now().millisecondsSinceEpoch}',
    };
  }
}

/// Обновить pubspec.yaml
Future<void> _updatePubspec(Map<String, String> gitInfo) async {
  final pubspecFile = File('pubspec.yaml');
  final content = await pubspecFile.readAsString();
  
  // Заменяем версию
  final newContent = content.replaceAll(
    RegExp(r'version:\s*[\d\.]+\+\d+'),
    'version: ${gitInfo['version']}+${gitInfo['buildNumber']}',
  );
  
  await pubspecFile.writeAsString(newContent);
  print('📝 pubspec.yaml обновлен');
}

/// Создать файл с информацией о сборке
Future<void> _createBuildInfoFile(Map<String, String> gitInfo) async {
  final buildInfoFile = File('lib/utils/build_info_data.dart');
  
  final content = '''
// Автоматически сгенерированный файл с информацией о сборке
// Не редактировать вручную!

class BuildInfoData {
  static const String version = '${gitInfo['version']}';
  static const String buildNumber = '${gitInfo['buildNumber']}';
  static const String commitHash = '${gitInfo['commitHash']}';
  static const String buildDate = '${gitInfo['buildDate']}';
  static const String fullCommitHash = '${gitInfo['fullCommitHash']}';
}
''';
  
  await buildInfoFile.writeAsString(content);
  print('📄 build_info_data.dart создан');
}
