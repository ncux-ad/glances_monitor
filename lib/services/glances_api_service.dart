import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';

class GlancesApiService {
  static const int timeoutSeconds = 10; // Увеличиваем таймаут до 10 секунд
  static const int slowEndpointTimeoutSeconds = 15; // Для медленных endpoints
  late final Dio _dio;
  late final Dio _slowDio; // Отдельный Dio для медленных endpoints
  
  // Кэш для результатов проверки endpoints
  static final Map<String, Map<String, bool>> _endpointCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5); // Кэш действителен 5 минут

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
    // Основной Dio для быстрых запросов
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
    _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds);
    
    // Отдельный Dio для медленных endpoints
    _slowDio = Dio();
    _slowDio.options.connectTimeout = Duration(seconds: slowEndpointTimeoutSeconds);
    _slowDio.options.receiveTimeout = Duration(seconds: slowEndpointTimeoutSeconds);
    
    // Добавляем перехватчики для логирования ошибок
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        print('API Error: ${error.message}');
        handler.next(error);
      },
    ));
    
    _slowDio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        print('Slow API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  // Категории endpoints по скорости выполнения
  static const List<String> fastEndpoints = [
    'quicklook', 'mem', 'cpu', 'network', 'fs', 'uptime', 'system', 'version'
  ];
  
  static const List<String> slowEndpoints = [
    'processlist', 'programlist', 'sensors', 'smart', 'raid', 'docker', 
    'gpu', 'diskio', 'folders', 'wifi', 'alert', 'connections', 
    'containers', 'ports', 'vms', 'amps', 'cloud', 'irq', 'help'
  ];

  void _setupAuth(ServerConfig server) {
    final authHeader = server.username.isNotEmpty && server.password.isNotEmpty
        ? 'Basic ${base64Encode(utf8.encode('${server.username}:${server.password}'))}'
        : null;
    
    // Настраиваем авторизацию для обоих Dio
    if (authHeader != null) {
      _dio.options.headers['Authorization'] = authHeader;
      _slowDio.options.headers['Authorization'] = authHeader;
    } else {
      _dio.options.headers.remove('Authorization');
      _slowDio.options.headers.remove('Authorization');
    }
  }

  // Получить ключ кэша для сервера
  String _getCacheKey(ServerConfig server) {
    return '${server.url}_${server.username}';
  }

  // Проверить, действителен ли кэш
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheValidityDuration;
  }

  // Получить кэшированные результаты
  Map<String, bool>? _getCachedResults(String cacheKey) {
    if (!_isCacheValid(cacheKey)) {
      _endpointCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return null;
    }
    return _endpointCache[cacheKey];
  }

  // Сохранить результаты в кэш
  void _cacheResults(String cacheKey, Map<String, bool> results) {
    _endpointCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = DateTime.now();
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

      // Разделяем endpoints на быстрые и медленные
      final fastEndpointsToFetch = endpointsToFetch.where((ep) => fastEndpoints.contains(ep)).toList();
      final slowEndpointsToFetch = endpointsToFetch.where((ep) => slowEndpoints.contains(ep)).toList();
      
      // Запрашиваем быстрые endpoints с обычным таймаутом
      final fastFutures = <Future<Response<dynamic>>>[];
      final slowFutures = <Future<Response<dynamic>>>[];
      final List<String> order = [];
      
      for (final ep in fastEndpointsToFetch) {
        order.add(ep);
        fastFutures.add(_dio.get('$apiUrl/$ep').catchError((error) {
          return Response(
            requestOptions: RequestOptions(path: '$apiUrl/$ep'),
            data: null,
            statusCode: 500,
          );
        }));
      }
      
      // Запрашиваем медленные endpoints с увеличенным таймаутом
      for (final ep in slowEndpointsToFetch) {
        order.add(ep);
        slowFutures.add(_slowDio.get('$apiUrl/$ep').catchError((error) {
          return Response(
            requestOptions: RequestOptions(path: '$apiUrl/$ep'),
            data: null,
            statusCode: 500,
          );
        }));
      }
      
      // Объединяем все futures
      final futures = [...fastFutures, ...slowFutures];

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
      List<Map<String, dynamic>>? gpu;
      List<Map<String, dynamic>>? diskio;
      List<Map<String, dynamic>>? folders;
      List<Map<String, dynamic>>? connections;
      List<Map<String, dynamic>>? containers;
      List<Map<String, dynamic>>? ports;
      List<Map<String, dynamic>>? vms;
      List<Map<String, dynamic>>? amps;
      List<Map<String, dynamic>>? cloud;
      List<Map<String, dynamic>>? ip;
      List<Map<String, dynamic>>? irq;
      List<Map<String, dynamic>>? programlist;
      Map<String, dynamic>? psutilversion;
      Map<String, dynamic>? help;
      Map<String, dynamic>? core;

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
          case 'gpu':
            if (data is List) {
              gpu = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'diskio':
            if (data is List) {
              diskio = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'folders':
            if (data is List) {
              folders = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'connections':
            if (data is List) {
              connections = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'containers':
            if (data is List) {
              containers = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'ports':
            if (data is List) {
              ports = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'vms':
            if (data is List) {
              vms = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'amps':
            if (data is List) {
              amps = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'cloud':
            if (data is List) {
              cloud = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'ip':
            if (data is List) {
              ip = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'irq':
            if (data is List) {
              irq = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'programlist':
            if (data is List) {
              programlist = data.map((item) {
                if (item is Map<String, dynamic>) return item;
                return <String, dynamic>{};
              }).toList();
            }
            break;
          case 'psutilversion':
            if (data is Map<String, dynamic>) psutilversion = data;
            break;
          case 'help':
            if (data is Map<String, dynamic>) help = data;
            break;
          case 'core':
            if (data is Map<String, dynamic>) core = data;
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
        gpu: gpu,
        diskio: diskio,
        folders: folders,
        connections: connections,
        containers: containers,
        ports: ports,
        vms: vms,
        amps: amps,
        cloud: cloud,
        ip: ip,
        irq: irq,
        programlist: programlist,
        psutilversion: psutilversion,
        help: help,
        core: core,
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

  // Сканирование доступных endpoint-ов на сервере (оптимизированным методом с кэшированием)
  Future<Map<String, bool>> scanAvailableEndpoints(ServerConfig server, {List<String>? endpoints}) async {
    final cacheKey = _getCacheKey(server);
    final toCheck = endpoints ?? knownEndpoints;
    
    // Проверяем кэш
    final cachedResults = _getCachedResults(cacheKey);
    if (cachedResults != null) {
      // Возвращаем только запрошенные endpoints из кэша
      final result = <String, bool>{};
      for (final ep in toCheck) {
        result[ep] = cachedResults[ep] ?? false;
      }
      return result;
    }

    _setupAuth(server);
    final apiVersion = await _determineApiVersion(server);
    final apiUrl = '${server.url}/api/$apiVersion';
    final Map<String, bool> result = {};

    // Разделяем endpoints на быстрые и медленные для оптимизации
    final fastEndpointsToCheck = toCheck.where((ep) => fastEndpoints.contains(ep)).toList();
    final slowEndpointsToCheck = toCheck.where((ep) => slowEndpoints.contains(ep)).toList();


    // Проверяем быстрые endpoints с коротким таймаутом
    await Future.wait(fastEndpointsToCheck.map((ep) async {
      try {
        final resp = await _dio.get('$apiUrl/$ep');
        result[ep] = (resp.statusCode == 200);
      } catch (_) {
        result[ep] = false;
      }
    }));

    // Проверяем медленные endpoints с увеличенным таймаутом
    await Future.wait(slowEndpointsToCheck.map((ep) async {
      try {
        final resp = await _slowDio.get('$apiUrl/$ep');
        result[ep] = (resp.statusCode == 200);
      } catch (_) {
        result[ep] = false;
      }
    }));

    // Сохраняем результаты в кэш
    _cacheResults(cacheKey, result);

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
