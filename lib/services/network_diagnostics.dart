import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';

class NetworkDiagnostics {
  static const int timeoutSeconds = 10;
  late final Dio _dio;

  NetworkDiagnostics() {
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
    _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds);
  }

  void _setupAuth(ServerConfig server) {
    if (server.username.isNotEmpty && server.password.isNotEmpty) {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<Map<String, dynamic>> diagnoseNetwork(ServerConfig server) async {
    final result = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'server': server.url,
      'api_version': null,
      'raw_network_data': null,
      'interfaces': <Map<String, dynamic>>[],
      'issues': <String>[],
      'recommendations': <String>[],
    };

    try {
      _setupAuth(server);
      
      // Определяем версию API
      int apiVersion = 4;
      try {
        await _dio.get('${server.url}/api/4/now');
        apiVersion = 4;
      } catch (e) {
        try {
          await _dio.get('${server.url}/api/3/now');
          apiVersion = 3;
        } catch (e) {
          result['issues'].add('Не удалось определить версию API (ни v3, ни v4)');
          return result;
        }
      }
      
      result['api_version'] = apiVersion;

      // Получаем сырые данные network endpoint
      final networkResponse = await _dio.get('${server.url}/api/$apiVersion/network');
      result['raw_network_data'] = networkResponse.data;

      if (networkResponse.data is List) {
        final List networkData = networkResponse.data as List;
        
        for (final iface in networkData) {
          if (iface is Map<String, dynamic>) {
            final interfaceInfo = <String, dynamic>{
              'name': iface['interface_name'] ?? 'unknown',
              'is_up': iface['is_up'] ?? false,
              'is_enabled': iface['is_enabled'] ?? false,
              'speed': iface['speed'] ?? 0,
              'cumulative_rx': iface['cumulative_rx'] ?? 0,
              'cumulative_tx': iface['cumulative_tx'] ?? 0,
              'rx': iface['rx'] ?? 0,
              'tx': iface['tx'] ?? 0,
              'rx_bytes_per_sec': iface['rx_bytes_per_sec'] ?? 0,
              'tx_bytes_per_sec': iface['tx_bytes_per_sec'] ?? 0,
              'raw_data': iface,
            };
            
            result['interfaces'].add(interfaceInfo);
            
            // Анализ проблем с улучшенной логикой
            final name = interfaceInfo['name'] as String;
            final isUp = interfaceInfo['is_up'] as bool;
            final cumulativeRx = interfaceInfo['cumulative_rx'] as num;
            final cumulativeTx = interfaceInfo['cumulative_tx'] as num;
            final rxPerSec = interfaceInfo['rx_bytes_per_sec'] as num;
            final txPerSec = interfaceInfo['tx_bytes_per_sec'] as num;
            
            // Проверяем сырые данные для более точной диагностики
            final rawData = iface;
            final bytesRecv = rawData['bytes_recv'] as num? ?? 0;
            final bytesSent = rawData['bytes_sent'] as num? ?? 0;
            final bytesRecvGauge = rawData['bytes_recv_gauge'] as num? ?? 0;
            final bytesSentGauge = rawData['bytes_sent_gauge'] as num? ?? 0;
            final hasRawActivity = bytesRecv > 0 || bytesSent > 0 || bytesRecvGauge > 0 || bytesSentGauge > 0;
            
            if (!isUp && !hasRawActivity) {
              result['issues'].add('Интерфейс $name не активен (is_up: false)');
            } else if (!isUp && hasRawActivity) {
              result['issues'].add('Интерфейс $name: неактивен в Glances, но есть сырые данные (возможно проблема с правами)');
            }
            
            if (cumulativeRx == 0 && cumulativeTx == 0 && !hasRawActivity) {
              result['issues'].add('Интерфейс $name: нулевая кумулятивная статистика');
            } else if (cumulativeRx == 0 && cumulativeTx == 0 && hasRawActivity) {
              result['issues'].add('Интерфейс $name: нулевая кумулятивная статистика, но есть активность в сырых данных');
            }
            
            if (rxPerSec == 0 && txPerSec == 0 && !hasRawActivity) {
              result['issues'].add('Интерфейс $name: нулевая скорость передачи');
            } else if (rxPerSec == 0 && txPerSec == 0 && hasRawActivity) {
              result['issues'].add('Интерфейс $name: нулевая скорость передачи, но есть активность в сырых данных');
            }
          }
        }
      } else {
        result['issues'].add('Network endpoint вернул неожиданный формат данных');
      }

      // Генерируем рекомендации на основе анализа
      if (result['issues'].isEmpty) {
        result['recommendations'].add('Сетевые интерфейсы работают нормально');
      } else {
        final hasRawDataIssues = result['issues'].any((issue) => (issue as String).contains('сырые данные'));
        
        if (hasRawDataIssues) {
          result['recommendations'].addAll([
            '⚠️ ПРОБЛЕМА С ПРАВАМИ: Glances не может получить корректную статистику сетевых интерфейсов',
            '🔧 Решение: Запустите Glances с правами root: sudo glances -w --port 61208',
            '🔧 Или добавьте пользователя glances в группу netdev: sudo usermod -aG netdev glances',
            '🔧 Проверьте права доступа к /proc/net/dev: ls -la /proc/net/dev',
            '🔧 Убедитесь что psutil имеет права на чтение сетевой статистики',
          ]);
        } else {
          result['recommendations'].addAll([
            'Проверьте статус сетевых интерфейсов: ip link show',
            'Проверьте активность: cat /proc/net/dev',
            'Убедитесь что Glances запущен с правами root или в группе netdev',
            'Проверьте что psutil установлен: pip install psutil',
            'Для VPS: убедитесь что виртуальные интерфейсы активны',
          ]);
        }
      }

    } catch (e) {
      result['issues'].add('Ошибка диагностики: $e');
      result['recommendations'].add('Проверьте подключение к серверу и права доступа');
    }

    return result;
  }

  Future<Map<String, dynamic>> testNetworkActivity(ServerConfig server) async {
    final result = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'test_results': <Map<String, dynamic>>[],
    };

    try {
      _setupAuth(server);
      
      // Получаем данные дважды с интервалом
      final response1 = await _dio.get('${server.url}/api/4/network');
      await Future.delayed(Duration(seconds: 2));
      final response2 = await _dio.get('${server.url}/api/4/network');
      
      if (response1.data is List && response2.data is List) {
        final List data1 = response1.data as List;
        final List data2 = response2.data as List;
        
        for (int i = 0; i < data1.length && i < data2.length; i++) {
          final iface1 = data1[i] as Map<String, dynamic>;
          final iface2 = data2[i] as Map<String, dynamic>;
          
          final name = iface1['interface_name'] as String? ?? 'unknown';
          final rx1 = (iface1['cumulative_rx'] as num?) ?? 0;
          final tx1 = (iface1['cumulative_tx'] as num?) ?? 0;
          final rx2 = (iface2['cumulative_rx'] as num?) ?? 0;
          final tx2 = (iface2['cumulative_tx'] as num?) ?? 0;
          
          final rxDiff = rx2 - rx1;
          final txDiff = tx2 - tx1;
          
          result['test_results'].add({
            'interface': name,
            'rx_change': rxDiff,
            'tx_change': txDiff,
            'has_activity': rxDiff > 0 || txDiff > 0,
            'data1': iface1,
            'data2': iface2,
          });
        }
      }
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }
}
