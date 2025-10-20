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
      
      // Определяем версию API (согласно документации Glances)
      int apiVersion = 4;
      try {
        // Сначала проверяем статус API v4
        final statusResponse = await _dio.get('${server.url}/api/4/status');
        if (statusResponse.statusCode == 200) {
          apiVersion = 4;
        } else {
          throw Exception('API v4 недоступен');
        }
      } catch (e) {
        try {
          // Fallback на API v3
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
            // Обрабатываем разные форматы API v3, v4 и FastAPI (4.3.3+)
            final interfaceInfo = <String, dynamic>{
              'name': iface['interface_name'] ?? 'unknown',
              'is_up': iface['is_up'], // Может отсутствовать в FastAPI
              'is_enabled': iface['is_enabled'] ?? false,
              'speed': iface['speed'] ?? 0,
              // Поддержка разных форматов данных
              'cumulative_rx': _safeParseNumber(iface['cumulative_rx'] ?? iface['bytes_recv'] ?? 0),
              'cumulative_tx': _safeParseNumber(iface['cumulative_tx'] ?? iface['bytes_sent'] ?? 0),
              'rx': iface['rx'] ?? 0,
              'tx': iface['tx'] ?? 0,
              // Поддержка разных полей для скорости
              'rx_bytes_per_sec': _safeParseNumber(iface['rx_bytes_per_sec'] ?? 
                                 iface['rx_rate_per_sec'] ?? 
                                 iface['bytes_recv_rate_per_sec'] ?? 0),
              'tx_bytes_per_sec': _safeParseNumber(iface['tx_bytes_per_sec'] ?? 
                                 iface['tx_rate_per_sec'] ?? 
                                 iface['bytes_sent_rate_per_sec'] ?? 0),
              // Новые поля FastAPI
              'bytes_recv_gauge': _safeParseNumber(iface['bytes_recv_gauge'] ?? 0),
              'bytes_sent_gauge': _safeParseNumber(iface['bytes_sent_gauge'] ?? 0),
              'bytes_recv_rate_per_sec': _safeParseNumber(iface['bytes_recv_rate_per_sec'] ?? 0),
              'bytes_sent_rate_per_sec': _safeParseNumber(iface['bytes_sent_rate_per_sec'] ?? 0),
              'raw_data': iface,
            };
            
            result['interfaces'].add(interfaceInfo);
            
            // Анализ проблем с поддержкой API v3, v4 и FastAPI (4.3.3+)
            final name = interfaceInfo['name'] as String;
            final isUp = interfaceInfo['is_up'];
            final cumulativeRx = interfaceInfo['cumulative_rx'] as num;
            final cumulativeTx = interfaceInfo['cumulative_tx'] as num;
            final rxPerSec = interfaceInfo['rx_bytes_per_sec'] as num;
            final txPerSec = interfaceInfo['tx_bytes_per_sec'] as num;
            
            // Продвинутая обработка сырых данных для всех версий API
            final rawData = iface;
            final bytesRecv = rawData['bytes_recv'] as num? ?? 0;
            final bytesSent = rawData['bytes_sent'] as num? ?? 0;
            final bytesRecvGauge = interfaceInfo['bytes_recv_gauge'] as num;
            final bytesSentGauge = interfaceInfo['bytes_sent_gauge'] as num;
            final bytesRecvRate = interfaceInfo['bytes_recv_rate_per_sec'] as num;
            final bytesSentRate = interfaceInfo['bytes_sent_rate_per_sec'] as num;
            
            // Определяем активность по множественным критериям
            final hasBasicActivity = bytesRecv > 0 || bytesSent > 0;
            final hasGaugeActivity = bytesRecvGauge > 0 || bytesSentGauge > 0;
            final hasRateActivity = bytesRecvRate > 0 || bytesSentRate > 0;
            final hasRawActivity = hasBasicActivity || hasGaugeActivity || hasRateActivity;
            
            // Дополнительная проверка для FastAPI - используем gauge данные как основной индикатор
            final isGaugeActive = bytesRecvGauge > 0 || bytesSentGauge > 0;
            final isRateActive = bytesRecvRate > 0 || bytesSentRate > 0;
            
            // Определяем активность интерфейса по данным о трафике
            final hasTrafficActivity = cumulativeRx > 0 || cumulativeTx > 0 || rxPerSec > 0 || txPerSec > 0;
            final isInterfaceActive = hasRawActivity || hasTrafficActivity;
            
            // Продвинутый анализ в зависимости от версии API
            if (apiVersion == 4) {
              // Проверяем, это FastAPI (4.3.3+) или обычный API v4
              final hasFastApiFields = bytesRecvGauge > 0 || bytesSentGauge > 0 || 
                                     bytesRecvRate > 0 || bytesSentRate > 0;
              
              if (isUp == null) {
                if (hasFastApiFields) {
                  // FastAPI 4.3.3+ - is_up отсутствует, используем gauge/rate данные
                  result['issues'].add('Интерфейс $name: FastAPI формат (is_up отсутствует)');
                  if (isGaugeActive) {
                    result['issues'].add('Интерфейс $name: активен по gauge данным (${_formatBytes(bytesRecvGauge)} RX, ${_formatBytes(bytesSentGauge)} TX)');
                  }
                  if (isRateActive) {
                    result['issues'].add('Интерфейс $name: активен по rate данным (${_formatBytes(bytesRecvRate)}/сек RX, ${_formatBytes(bytesSentRate)}/сек TX)');
                  }
                  if (!isGaugeActive && !isRateActive && !hasBasicActivity) {
                    result['issues'].add('Интерфейс $name: неактивен по всем показателям');
                  }
                } else {
                  // Обычный API v4 с багом is_up: null
                  result['issues'].add('Интерфейс $name: is_up = null (баг в Glances 4.3.3)');
                  if (isGaugeActive) {
                    result['issues'].add('Интерфейс $name: активен по gauge данным (${_formatBytes(bytesRecvGauge)} RX, ${_formatBytes(bytesSentGauge)} TX)');
                  }
                  if (isRateActive) {
                    result['issues'].add('Интерфейс $name: активен по rate данным (${_formatBytes(bytesRecvRate)}/сек RX, ${_formatBytes(bytesSentRate)}/сек TX)');
                  }
                  if (!isGaugeActive && !isRateActive && !hasBasicActivity) {
                    result['issues'].add('Интерфейс $name: неактивен по всем показателям');
                  }
                }
              } else if (isUp == false && isInterfaceActive) {
                result['issues'].add('Интерфейс $name: is_up=false, но есть активность по данным о трафике');
                if (isGaugeActive) {
                  result['issues'].add('Интерфейс $name: gauge активность (${_formatBytes(bytesRecvGauge)} RX, ${_formatBytes(bytesSentGauge)} TX)');
                }
              } else if (isUp == false && !isInterfaceActive) {
                result['issues'].add('Интерфейс $name не активен (is_up: false, нет трафика)');
              }
            } else {
              // API v3 - is_up работает корректно
              if (isUp == false && isInterfaceActive) {
                result['issues'].add('Интерфейс $name: is_up=false, но есть активность по данным о трафике');
              } else if (isUp == false && !isInterfaceActive) {
                result['issues'].add('Интерфейс $name не активен (is_up: false, нет трафика)');
              }
            }
            
            // Проверяем статистику трафика
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
        final hasGlancesBug = result['issues'].any((issue) => (issue as String).contains('баг в Glances 4.3.3'));
        final hasRawDataIssues = result['issues'].any((issue) => (issue as String).contains('сырые данные'));
        
        if (hasGlancesBug) {
          final hasFastApiFields = result['issues'].any((issue) => (issue as String).contains('FastAPI формат'));
          
          if (hasFastApiFields) {
            result['recommendations'].addAll([
              '🚀 ОБНАРУЖЕН FASTAPI: Glances 4.3.3+ с FastAPI архитектурой',
              '✅ РЕШЕНИЕ: Приложение обновлено для поддержки FastAPI формата',
              '📊 Диагностика использует продвинутую обработку gauge/rate данных',
              '🔍 Анализируются gauge данные (bytes_recv_gauge, bytes_sent_gauge)',
              '⚡ Проверяются rate данные (bytes_recv_rate_per_sec, bytes_sent_rate_per_sec)',
              '💡 FastAPI не передает поле is_up - это нормальное поведение',
              '🔄 Приложение корректно определяет активность по множественным критериям',
              '🎯 FastAPI обеспечивает более точную диагностику сетевой активности',
            ]);
          } else {
            result['recommendations'].addAll([
              '🐛 ОБНАРУЖЕН БАГ: Glances 4.3.3 не передает поле is_up в API v4',
              '✅ РЕШЕНИЕ: Приложение обновлено для обхода этого бага',
              '📊 Диагностика использует продвинутую обработку сырых данных',
              '🔍 Анализируются gauge данные (bytes_recv_gauge, bytes_sent_gauge)',
              '⚡ Проверяются rate данные (bytes_recv_rate_per_sec, bytes_sent_rate_per_sec)',
              '🔧 Для полного исправления обновите Glances до версии 4.4.0+',
              '💡 Временное решение: приложение корректно определяет активность по множественным критериям',
              '🔄 Альтернатива: используйте API v3 для более точной диагностики',
            ]);
          }
        } else if (hasRawDataIssues) {
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
          
          // Для FastAPI используем bytes_recv/bytes_sent, для обычного API - cumulative_rx/cumulative_tx
          final rx1 = _safeParseNumber(iface1['cumulative_rx'] ?? iface1['bytes_recv'] ?? 0);
          final tx1 = _safeParseNumber(iface1['cumulative_tx'] ?? iface1['bytes_sent'] ?? 0);
          final rx2 = _safeParseNumber(iface2['cumulative_rx'] ?? iface2['bytes_recv'] ?? 0);
          final tx2 = _safeParseNumber(iface2['cumulative_tx'] ?? iface2['bytes_sent'] ?? 0);
          
          // Дополнительная проверка для FastAPI - используем gauge данные если доступны
          final rx1Gauge = _safeParseNumber(iface1['bytes_recv_gauge'] ?? 0);
          final tx1Gauge = _safeParseNumber(iface1['bytes_sent_gauge'] ?? 0);
          final rx2Gauge = _safeParseNumber(iface2['bytes_recv_gauge'] ?? 0);
          final tx2Gauge = _safeParseNumber(iface2['bytes_sent_gauge'] ?? 0);
          
          // Вычисляем изменения
          final rxDiff = rx2 - rx1;
          final txDiff = tx2 - tx1;
          final rxGaugeDiff = rx2Gauge - rx1Gauge;
          final txGaugeDiff = tx2Gauge - tx1Gauge;
          
          // Используем gauge данные если они показывают активность, иначе обычные данные
          final finalRxDiff = rxGaugeDiff != 0 ? rxGaugeDiff : rxDiff;
          final finalTxDiff = txGaugeDiff != 0 ? txGaugeDiff : txDiff;
          
          result['test_results'].add({
            'interface': name,
            'rx_change': finalRxDiff,
            'tx_change': finalTxDiff,
            'has_activity': finalRxDiff > 0 || finalTxDiff > 0,
            'raw_rx_change': rxDiff,
            'raw_tx_change': txDiff,
            'gauge_rx_change': rxGaugeDiff,
            'gauge_tx_change': txGaugeDiff,
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

  String _formatBytes(num bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    int i = 0;
    double size = bytes.toDouble();
    while (size >= k && i < sizes.length - 1) {
      size /= k;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${sizes[i]}';
  }

  num _safeParseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) {
      // Проверяем на Infinity и NaN
      if (value.isInfinite || value.isNaN) return 0;
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed == null) return 0;
      if (parsed.isInfinite || parsed.isNaN) return 0;
      return parsed;
    }
    return 0;
  }
}
