import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';

class EndpointDiagnostics {
  static const int timeoutSeconds = 10;
  late final Dio _dio;

  EndpointDiagnostics() {
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

  Future<Map<String, dynamic>> diagnoseEndpoint(ServerConfig server, String endpoint) async {
    final result = <String, dynamic>{
      'endpoint': endpoint,
      'timestamp': DateTime.now().toIso8601String(),
      'server': server.url,
      'api_version': null,
      'status_code': null,
      'response_time_ms': null,
      'error_message': null,
      'raw_data': null,
      'data_size_bytes': null,
      'is_available': false,
      'issues': <String>[],
      'recommendations': <String>[],
    };

    final stopwatch = Stopwatch()..start();

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
          result['recommendations'].add('Проверьте что Glances запущен и доступен');
          return result;
        }
      }
      
      result['api_version'] = apiVersion;

      // Тестируем конкретный endpoint
      final response = await _dio.get('${server.url}/api/$apiVersion/$endpoint');
      stopwatch.stop();
      
      result['status_code'] = response.statusCode;
      result['response_time_ms'] = stopwatch.elapsedMilliseconds;
      result['raw_data'] = response.data;
      result['data_size_bytes'] = response.data.toString().length;
      result['is_available'] = response.statusCode == 200;

      // Анализ данных
      if (response.data == null) {
        result['issues'].add('Endpoint вернул null данные');
      } else if (response.data is List && (response.data as List).isEmpty) {
        result['issues'].add('Endpoint вернул пустой список');
      } else if (response.data is Map && (response.data as Map).isEmpty) {
        result['issues'].add('Endpoint вернул пустой объект');
      }

      // Специфичные проверки для разных endpoint
      _analyzeEndpointSpecific(endpoint, response.data, result);

    } catch (e) {
      stopwatch.stop();
      result['response_time_ms'] = stopwatch.elapsedMilliseconds;
      result['error_message'] = e.toString();
      result['is_available'] = false;
      
      if (e is DioException) {
        result['status_code'] = e.response?.statusCode;
        
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
            result['issues'].add('Таймаут подключения');
            result['recommendations'].add('Увеличьте таймаут или проверьте сеть');
            break;
          case DioExceptionType.receiveTimeout:
            result['issues'].add('Таймаут получения данных');
            result['recommendations'].add('Endpoint медленно отвечает, увеличьте таймаут');
            break;
          case DioExceptionType.badResponse:
            result['issues'].add('HTTP ошибка: ${e.response?.statusCode}');
            result['recommendations'].add('Проверьте права доступа и конфигурацию сервера');
            break;
          case DioExceptionType.connectionError:
            result['issues'].add('Ошибка подключения');
            result['recommendations'].add('Проверьте доступность сервера и порт');
            break;
          default:
            result['issues'].add('Неизвестная ошибка: ${e.type}');
        }
      } else {
        result['issues'].add('Общая ошибка: $e');
        result['recommendations'].add('Проверьте подключение к серверу');
      }
    }

    // Генерируем общие рекомендации
    _generateGeneralRecommendations(endpoint, result);

    return result;
  }

  void _analyzeEndpointSpecific(String endpoint, dynamic data, Map<String, dynamic> result) {
    switch (endpoint) {
      case 'sensors':
        if (data is List && data.isEmpty) {
          result['issues'].add('Нет данных от датчиков');
          result['recommendations'].add('Установите lm-sensors: sudo apt install lm-sensors && sudo sensors-detect');
        }
        break;
      case 'smart':
        if (data is List && data.isEmpty) {
          result['issues'].add('Нет SMART данных');
          result['recommendations'].add('Установите smartmontools: sudo apt install smartmontools');
        }
        break;
      case 'raid':
        if (data is List && data.isEmpty) {
          result['issues'].add('Нет RAID данных');
          result['recommendations'].add('Установите mdadm: sudo apt install mdadm');
        }
        break;
      case 'docker':
        if (data is List && data.isEmpty) {
          result['issues'].add('Нет Docker контейнеров');
          result['recommendations'].add('Добавьте пользователя glances в группу docker: sudo usermod -aG docker glances');
        }
        break;
      case 'wifi':
        if (data is List && data.isEmpty) {
          result['issues'].add('Нет Wi-Fi интерфейсов');
          result['recommendations'].add('Wi-Fi доступен только на системах с Wi-Fi адаптером');
        }
        break;
      case 'processlist':
        if (data is List && data.length > 1000) {
          result['issues'].add('Слишком много процессов (${data.length})');
          result['recommendations'].add('Ограничьте количество процессов для производительности');
        }
        break;
    }
  }

  void _generateGeneralRecommendations(String endpoint, Map<String, dynamic> result) {
    if (result['is_available'] == true) {
      result['recommendations'].add('Endpoint работает корректно');
      return;
    }

    // Общие рекомендации по endpoint
    final endpointTips = {
      'sensors': [
        'Установите lm-sensors: sudo apt install lm-sensors',
        'Запустите sensors-detect: sudo sensors-detect',
        'Проверьте права доступа к /sys/class/thermal_zone'
      ],
      'smart': [
        'Установите smartmontools: sudo apt install smartmontools',
        'Проверьте права доступа к дискам: sudo smartctl -a /dev/sda',
        'Убедитесь что диски поддерживают SMART'
      ],
      'raid': [
        'Установите mdadm: sudo apt install mdadm',
        'Проверьте статус RAID: cat /proc/mdstat',
        'Убедитесь что RAID массив активен'
      ],
      'docker': [
        'Установите Docker: sudo apt install docker.io',
        'Добавьте пользователя в группу docker: sudo usermod -aG docker glances',
        'Перезапустите Docker: sudo systemctl restart docker'
      ],
      'wifi': [
        'Wi-Fi доступен только на системах с Wi-Fi адаптером',
        'Проверьте что Wi-Fi интерфейс активен: ip link show wlan0',
        'Убедитесь что iwconfig установлен: sudo apt install wireless-tools'
      ],
      'processlist': [
        'Ограничьте количество процессов для производительности',
        'Используйте фильтрацию по CPU или памяти',
        'Рассмотрите использование processcount вместо processlist'
      ]
    };

    final tips = endpointTips[endpoint] ?? [
      'Проверьте что Glances запущен с правами root',
      'Убедитесь что все зависимости установлены',
      'Проверьте логи Glances: journalctl -u glances'
    ];

    result['recommendations'].addAll(tips);
  }

  Future<Map<String, dynamic>> testAllEndpoints(ServerConfig server) async {
    final endpoints = [
      'quicklook', 'mem', 'memswap', 'fs', 'cpu', 'network',
      'uptime', 'system', 'version', 'processcount', 'processlist',
      'sensors', 'smart', 'raid', 'docker', 'wifi', 'load', 'alert'
    ];

    final results = <String, dynamic>{};
    
    for (final endpoint in endpoints) {
      try {
        final result = await diagnoseEndpoint(server, endpoint);
        results[endpoint] = result;
      } catch (e) {
        results[endpoint] = {
          'endpoint': endpoint,
          'is_available': false,
          'error_message': e.toString(),
          'issues': ['Ошибка диагностики: $e'],
          'recommendations': ['Проверьте подключение к серверу']
        };
      }
    }

    return results;
  }
}
