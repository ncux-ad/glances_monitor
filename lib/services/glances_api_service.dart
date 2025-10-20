import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';

class GlancesApiService {
  static const int timeoutSeconds = 5;
  late final Dio _dio;

  // Реестр известных endpoint-ов Glances (согласно официальной документации)
  static const List<String> knownEndpoints = [
    'quicklook',      // Сводная информация
    'mem',           // Память
    'memswap',       // Своп память
    'fs',            // Файловая система
    'cpu',           // Процессор
    'network',       // Сетевые интерфейсы
    'percpu',        // Процессор по ядрам
    'load',          // Нагрузка системы
    'uptime',        // Время работы
    'system',        // Информация о системе
    'version',       // Версия Glances
    'processcount',  // Количество процессов
    'processlist',   // Список процессов
    'sensors',       // Датчики
    'smart',         // SMART диски
    'raid',          // RAID массивы
    'docker',        // Docker контейнеры
    'gpu',           // Видеокарты
    'diskio',        // Дисковая активность
    'folders',       // Папки
    'wifi',          // WiFi
    'alert',         // Оповещения
    'connections',   // Сетевые соединения
    'containers',    // Контейнеры
    'ports',         // Порты
    'vms',           // Виртуальные машины
    'amps',          // AMP мониторинг
    'cloud',         // Облачные сервисы
    'ip',            // IP адреса
    'irq',           // Прерывания
    'programlist',   // Список программ
    'psutilversion', // Версия psutil
    'help',          // Справка
    'core',          // Ядро системы
  ];


  GlancesApiService() {
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
    _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds);
    
    // Добавляем перехватчик для логирования ошибок
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        print('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  void _setupAuth(ServerConfig server) {
    if (server.username.isNotEmpty && server.password.isNotEmpty) {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<int> _determineApiVersion(ServerConfig server) async {
    try {
      // Согласно документации Glances, используем /api/4/status для проверки
      final statusResponse = await _dio.get('${server.url}/api/4/status');
      if (statusResponse.statusCode == 200) {
        return 4;
      } else {
        throw Exception('API v4 недоступен');
      }
    } catch (e) {
      // Если v4 недоступна, пробуем v3
      try {
        await _dio.get('${server.url}/api/3/now');
        return 3;
      } catch (e) {
        // Если и v3 недоступна, выбрасываем исключение
        throw Exception('Не удалось определить версию API');
      }
    }
  }

  Future<SystemMetrics> fetchMetrics(ServerConfig server) async {
    return getServerMetrics(server);
  }

  Future<SystemMetrics> getServerMetrics(ServerConfig server) async {
    try {
      _setupAuth(server);
      final apiVersion = await _determineApiVersion(server); // Получаем версию API

      final apiUrl = '${server.url}/api/$apiVersion';

      // Определяем, какие эндпоинты нужны на основе выбранных метрик и selectedEndpoints
      final needCpu = server.selectedMetrics.contains('cpu');
      final needMem = server.selectedMetrics.contains('mem');
      final needFs = server.selectedMetrics.contains('fs');
      final needNetwork = server.selectedMetrics.contains('network');
      final needSwap = server.selectedMetrics.contains('swap');

      // Привязка метрик к endpoint-ам (минимальный набор)
      final Set<String> endpointsToFetch = {
        'quicklook',
        if (needMem) 'mem',
        if (needSwap) 'memswap',
        if (needFs) 'fs',
        if (needCpu) 'cpu',
        if (needNetwork) 'network',
      };
      // Учитываем явный выбор endpoint-ов пользователя (пересечение с известными)
      for (final ep in server.selectedEndpoints) {
        if (knownEndpoints.contains(ep)) endpointsToFetch.add(ep);
      }

      // Всегда запрашиваем quicklook (сводная информация)
      final futures = <Future<Response<dynamic>>>[];
      final List<String> order = [];
      for (final ep in endpointsToFetch) {
        order.add(ep);
        futures.add(_dio.get('$apiUrl/$ep').catchError((error) {
          // Возвращаем пустой ответ для неудачных запросов
          return Response(
            requestOptions: RequestOptions(path: '$apiUrl/$ep'),
            data: null,
            statusCode: 500,
          );
        }));
      }

      final responses = await Future.wait(futures, eagerError: false);

      // Раскладываем ответы в известные структуры
      Map<String, dynamic> quicklook = const {};
      Map<String, dynamic> mem = const {'percent': 0, 'total': 0, 'used': 0, 'free': 0};
      Map<String, dynamic> memswap = const {'percent': 0, 'total': 0, 'used': 0, 'free': 0};
      List<dynamic> fs = const [];
      Map<String, dynamic> cpu = const {};
      List<dynamic> network = const [];
      String? uptimeText;
      Map<String, dynamic>? systemInfo;
      Map<String, dynamic>? versionInfo;
      Map<String, dynamic>? processCount;
      List<Map<String, dynamic>>? processList;
      List<Map<String, dynamic>>? sensors;
      List<Map<String, dynamic>>? smart;
      List<Map<String, dynamic>>? raid;
      List<Map<String, dynamic>>? docker;
      List<Map<String, dynamic>>? wifi;
      Map<String, dynamic>? load;
      Map<String, dynamic>? alert;

      for (int i = 0; i < order.length; i++) {
        final ep = order[i];
        final response = responses[i];
        final data = response.data;
        
        // Пропускаем обработку если запрос не удался
        if (response.statusCode != 200 || data == null) {
          continue;
        }
        
        switch (ep) {
          case 'quicklook':
            if (data is Map<String, dynamic>) quicklook = data;
            break;
          case 'mem':
            if (data is Map<String, dynamic>) mem = data;
            break;
          case 'memswap':
            if (data is Map<String, dynamic>) memswap = data;
            break;
          case 'fs':
            if (data is List) fs = data;
            break;
          case 'cpu':
            if (data is Map<String, dynamic>) cpu = data;
            break;
          case 'network':
            if (data is List) {
              // Фильтруем по выбранным интерфейсам, если заданы на сервере
              if (server.selectedNetworkInterfaces.isNotEmpty) {
                network = data.where((iface) {
                  final name = (iface is Map && iface['interface_name'] is String) ? iface['interface_name'] as String : '';
                  return server.selectedNetworkInterfaces.contains(name);
                }).toList();
              } else {
                network = data;
              }
            }
            break;
          case 'uptime':
            // v3/v4 могут отдавать строку
            if (data is String) uptimeText = data;
            break;
          case 'system':
            if (data is Map<String, dynamic>) systemInfo = data;
            break;
          case 'version':
            if (data is Map<String, dynamic>) versionInfo = data;
            break;
          case 'processcount':
            if (data is Map<String, dynamic>) processCount = data;
            break;
          case 'processlist':
            if (data is List) {
              processList = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'sensors':
            if (data is List) {
              sensors = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'smart':
            if (data is List) {
              smart = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'raid':
            if (data is List) {
              raid = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'docker':
            if (data is List) {
              docker = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'wifi':
            if (data is List) {
              wifi = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'load':
            if (data is Map<String, dynamic>) load = data;
            break;
          case 'alert':
            if (data is Map<String, dynamic>) alert = data;
            break;
          default:
            // Прочие endpoint игнорируем на уровне текущей модели, но они уже не грузятся, если не нужны
            break;
        }
      }

      return SystemMetrics.fromGlancesData(
        quicklook: quicklook,
        memory: mem,
        memswap: memswap,
        disk: fs,
        cpu: cpu,
        network: network,
        apiVersion: apiVersion,
        uptimeText: uptimeText,
        systemInfo: systemInfo,
        versionInfo: versionInfo,
        processCount: processCount,
        processList: processList,
        sensors: sensors,
        smart: smart,
        raid: raid,
        docker: docker,
        wifi: wifi,
        load: load,
        alert: alert,
      );
    } on DioException catch (e) {
      return SystemMetrics.offline(errorMessage: e.message);
    } catch (e) {
      return SystemMetrics.offline(errorMessage: e.toString());
    }
  }

  Future<bool> testConnection(ServerConfig server) async {
    try {
      _setupAuth(server);
      final apiVersion = await _determineApiVersion(server); // Получаем версию API
      
      // Согласно документации, используем /status для проверки API v4
      if (apiVersion == 4) {
        final response = await _dio.get('${server.url}/api/4/status');
        return response.statusCode == 200;
      } else {
        // Для API v3 используем /now
        final response = await _dio.get('${server.url}/api/3/now');
        return response.statusCode == 200;
      }
    } catch (e) {
      return false;
    }
  }

  // Сканирование доступных endpoint-ов на сервере (быстрым методом)
  Future<Map<String, bool>> scanAvailableEndpoints(ServerConfig server, {List<String>? endpoints}) async {
    _setupAuth(server);
    final apiVersion = await _determineApiVersion(server); // Получаем версию API
    final apiUrl = '${server.url}/api/$apiVersion';
    final toCheck = endpoints ?? knownEndpoints;
    final Map<String, bool> result = {};

    await Future.wait(toCheck.map((ep) async {
      try {
        final resp = await _dio.get('$apiUrl/$ep');
        result[ep] = (resp.statusCode == 200);
      } catch (_) {
        result[ep] = false;
      }
    }));

    return result;
  }

  // Получить список сетевых интерфейсов
  Future<List<String>> fetchNetworkInterfaces(ServerConfig server) async {
    _setupAuth(server);
    final apiVersion = await _determineApiVersion(server); // Получаем версию API
    final apiUrl = '${server.url}/api/$apiVersion/network';
    try {
      final resp = await _dio.get(apiUrl);
      if (resp.statusCode == 200 && resp.data is List) {
        final List data = resp.data as List;
        return data.map((e) {
          if (e is Map && e['interface_name'] is String) return e['interface_name'] as String;
          return '';
        }).where((name) => name.isNotEmpty).cast<String>().toList();
      }
    } catch (_) {}
    return [];
  }
}
