import 'dart:io';
import '../models/server_config.dart';

class NetworkLogGenerator {
  static String generateNetworkDiagnosticLog({
    required Map<String, dynamic> diagnosticData,
    required ServerConfig server,
    String? additionalNotes,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final log = StringBuffer();
    
    // Заголовок
    log.writeln('=' * 80);
    log.writeln('ДИАГНОСТИКА СЕТИ GLANCES MONITOR');
    log.writeln('=' * 80);
    log.writeln();
    
    // Информация о сессии
    log.writeln('📅 Время диагностики: $timestamp');
    log.writeln('🖥️  Сервер: ${server.name} (${server.url})');
    log.writeln('🔧 Версия API: ${diagnosticData['api_version'] ?? 'Неизвестно'}');
    log.writeln();
    
    // Сводка
    final interfaces = diagnosticData['interfaces'] as List<dynamic>? ?? [];
    final issues = diagnosticData['issues'] as List<dynamic>? ?? [];
    final recommendations = diagnosticData['recommendations'] as List<dynamic>? ?? [];
    
    log.writeln('📊 СВОДКА:');
    log.writeln('   • Интерфейсов найдено: ${interfaces.length}');
    log.writeln('   • Проблем обнаружено: ${issues.length}');
    log.writeln('   • Рекомендаций: ${recommendations.length}');
    log.writeln();
    
    // Проблемы
    if (issues.isNotEmpty) {
      log.writeln('⚠️  ОБНАРУЖЕННЫЕ ПРОБЛЕМЫ:');
      for (int i = 0; i < issues.length; i++) {
        log.writeln('   ${i + 1}. ${issues[i]}');
      }
      log.writeln();
    }
    
    // Рекомендации
    if (recommendations.isNotEmpty) {
      log.writeln('💡 РЕКОМЕНДАЦИИ:');
      for (int i = 0; i < recommendations.length; i++) {
        log.writeln('   ${i + 1}. ${recommendations[i]}');
      }
      log.writeln();
    }
    
    // Детальная информация по интерфейсам
    if (interfaces.isNotEmpty) {
      log.writeln('🌐 СЕТЕВЫЕ ИНТЕРФЕЙСЫ:');
      log.writeln('-' * 40);
      
      for (final iface in interfaces) {
        final name = iface['name'] as String? ?? 'unknown';
        final isUp = iface['is_up'] as bool? ?? false;
        final cumulativeRx = iface['cumulative_rx'] as num? ?? 0;
        final cumulativeTx = iface['cumulative_tx'] as num? ?? 0;
        final rxPerSec = iface['rx_bytes_per_sec'] as num? ?? 0;
        final txPerSec = iface['tx_bytes_per_sec'] as num? ?? 0;
        
        log.writeln('Интерфейс: $name');
        log.writeln('   Статус: ${isUp ? "Активен" : "Неактивен"}');
        log.writeln('   Кумулятивный RX: ${_formatBytes(cumulativeRx)}');
        log.writeln('   Кумулятивный TX: ${_formatBytes(cumulativeTx)}');
        log.writeln('   Скорость RX: ${_formatBytes(rxPerSec)}/сек');
        log.writeln('   Скорость TX: ${_formatBytes(txPerSec)}/сек');
        log.writeln();
      }
    }
    
    // Сырые данные
    if (diagnosticData['raw_network_data'] != null) {
      log.writeln('🔍 СЫРЫЕ ДАННЫЕ:');
      log.writeln('-' * 40);
      log.writeln(diagnosticData['raw_network_data'].toString());
      log.writeln();
    }
    
    // Системная информация
    log.writeln('💻 СИСТЕМНАЯ ИНФОРМАЦИЯ:');
    log.writeln('-' * 40);
    log.writeln('Операционная система: ${Platform.operatingSystem}');
    log.writeln('Версия: ${Platform.operatingSystemVersion}');
    log.writeln('Архитектура: ${Platform.operatingSystemVersion}');
    log.writeln();
    
    // Дополнительные заметки
    if (additionalNotes != null && additionalNotes.isNotEmpty) {
      log.writeln('📝 ДОПОЛНИТЕЛЬНЫЕ ЗАМЕТКИ:');
      log.writeln('-' * 40);
      log.writeln(additionalNotes);
      log.writeln();
    }
    
    // Подпись
    log.writeln('=' * 80);
    log.writeln('Сгенерировано Glances Monitor App');
    log.writeln('Для получения помощи отправьте этот лог разработчикам');
    log.writeln('=' * 80);
    
    return log.toString();
  }
  
  static String generateEndpointDiagnosticLog({
    required Map<String, dynamic> diagnosticResults,
    required ServerConfig server,
    String? additionalNotes,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final log = StringBuffer();
    
    // Заголовок
    log.writeln('=' * 80);
    log.writeln('ДИАГНОСТИКА ENDPOINT GLANCES MONITOR');
    log.writeln('=' * 80);
    log.writeln();
    
    // Информация о сессии
    log.writeln('📅 Время диагностики: $timestamp');
    log.writeln('🖥️  Сервер: ${server.name} (${server.url})');
    log.writeln();
    
    // Сводка по endpoint
    final available = diagnosticResults.values.where((r) => r['is_available'] == true).length;
    final total = diagnosticResults.length;
    final issues = diagnosticResults.values.where((r) => (r['issues'] as List).isNotEmpty).length;
    
    log.writeln('📊 СВОДКА ПО ENDPOINT:');
    log.writeln('   • Доступно endpoint: $available из $total');
    log.writeln('   • Проблем обнаружено: $issues');
    log.writeln();
    
    // Детальная информация по каждому endpoint
    log.writeln('🔍 ДЕТАЛЬНАЯ ИНФОРМАЦИЯ ПО ENDPOINT:');
    log.writeln('-' * 60);
    
    for (final entry in diagnosticResults.entries) {
      final endpoint = entry.key;
      final result = entry.value;
      
      final isAvailable = result['is_available'] as bool? ?? false;
      final statusCode = result['status_code'] as int?;
      final responseTime = result['response_time_ms'] as int?;
      final issues = result['issues'] as List<dynamic>? ?? [];
      final recommendations = result['recommendations'] as List<dynamic>? ?? [];
      
      log.writeln('Endpoint: $endpoint');
      log.writeln('   Статус: ${isAvailable ? "Доступен" : "Недоступен"}');
      if (statusCode != null) log.writeln('   HTTP код: $statusCode');
      if (responseTime != null) log.writeln('   Время ответа: ${responseTime}ms');
      
      if (issues.isNotEmpty) {
        log.writeln('   Проблемы:');
        for (final issue in issues) {
          log.writeln('     • $issue');
        }
      }
      
      if (recommendations.isNotEmpty) {
        log.writeln('   Рекомендации:');
        for (final rec in recommendations) {
          log.writeln('     • $rec');
        }
      }
      
      log.writeln();
    }
    
    // Дополнительные заметки
    if (additionalNotes != null && additionalNotes.isNotEmpty) {
      log.writeln('📝 ДОПОЛНИТЕЛЬНЫЕ ЗАМЕТКИ:');
      log.writeln('-' * 40);
      log.writeln(additionalNotes);
      log.writeln();
    }
    
    // Подпись
    log.writeln('=' * 80);
    log.writeln('Сгенерировано Glances Monitor App');
    log.writeln('Для получения помощи отправьте этот лог разработчикам');
    log.writeln('=' * 80);
    
    return log.toString();
  }
  
  static String _formatBytes(num bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    final i = (bytes / k).floor();
    final clampedIndex = i < sizes.length ? i : sizes.length - 1;
    return '${(bytes / (k * clampedIndex)).toStringAsFixed(1)} ${sizes[clampedIndex]}';
  }
}
