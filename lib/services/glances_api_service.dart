import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';

class GlancesApiService {
  static const int timeoutSeconds = 5;
  late final Dio _dio;

  GlancesApiService() {
    _dio = Dio();
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
    _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds);
  }

  Future<SystemMetrics> fetchMetrics(ServerConfig server) async {
    return getServerMetrics(server);
  }

  Future<SystemMetrics> getServerMetrics(ServerConfig server) async {
    try {
      print('🌐 Запрос к серверу: ${server.url}');
      
      // Настройка Basic Auth только если указаны username и password
      if (server.username.isNotEmpty && server.password.isNotEmpty) {
        final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
        _dio.options.headers['Authorization'] = 'Basic $auth';
        print('🔐 Используется Basic Auth для ${server.username}');
      } else {
        _dio.options.headers.remove('Authorization');
        print('🔓 Без аутентификации');
      }

      // Параллельные запросы к API согласно документации Glances
      print('📡 Отправка запросов к API...');
      final responses = await Future.wait([
        _dio.get('${server.url}/api/4/quicklook'),
        _dio.get('${server.url}/api/4/mem'),
        _dio.get('${server.url}/api/4/memswap'),
        _dio.get('${server.url}/api/4/fs'),
        _dio.get('${server.url}/api/4/cpu'),
        _dio.get('${server.url}/api/4/network'),
      ]);
      print('✅ Все API запросы выполнены успешно');

      return SystemMetrics.fromGlancesData(
        quicklook: responses[0].data as Map<String, dynamic>,
        memory: responses[1].data as Map<String, dynamic>,
        memswap: responses[2].data as Map<String, dynamic>,
        disk: responses[3].data as List<dynamic>,
        cpu: responses[4].data as Map<String, dynamic>,
        network: responses[5].data as List<dynamic>,
      );
    } on DioException catch (e) {
      print('❌ DioException для сервера ${server.name}: ${e.message}');
      print('❌ Статус код: ${e.response?.statusCode}');
      print('❌ URL: ${e.requestOptions.uri}');
      return SystemMetrics.offline(errorMessage: e.message);
    } catch (e) {
      print('❌ Неожиданная ошибка для сервера ${server.name}: $e');
      print('❌ Тип ошибки: ${e.runtimeType}');
      return SystemMetrics.offline(errorMessage: e.toString());
    }
  }

  Future<bool> testConnection(ServerConfig server) async {
    try {
      // Настройка Basic Auth только если указаны username и password
      if (server.username.isNotEmpty && server.password.isNotEmpty) {
        final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
        _dio.options.headers['Authorization'] = 'Basic $auth';
      } else {
        _dio.options.headers.remove('Authorization');
      }
      
      final response = await _dio.get('${server.url}/api/4/now');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Ошибка подключения к ${server.name}: ${e.message}');
      return false;
    } catch (e) {
      print('Неожиданная ошибка подключения к ${server.name}: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getQuicklook(ServerConfig server) async {
    try {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
      
      final response = await _dio.get('${server.url}/api/4/quicklook');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Ошибка получения quicklook для ${server.name}: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMemory(ServerConfig server) async {
    try {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
      
      final response = await _dio.get('${server.url}/api/4/mem');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Ошибка получения memory для ${server.name}: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getDisk(ServerConfig server) async {
    try {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
      
      final response = await _dio.get('${server.url}/api/4/fs');
      return response.data as List<dynamic>?;
    } catch (e) {
      print('Ошибка получения disk для ${server.name}: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCpu(ServerConfig server) async {
    try {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
      
      final response = await _dio.get('${server.url}/api/4/cpu');
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      print('Ошибка получения cpu для ${server.name}: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getNetwork(ServerConfig server) async {
    try {
      final auth = base64Encode(utf8.encode('${server.username}:${server.password}'));
      _dio.options.headers['Authorization'] = 'Basic $auth';
      
      final response = await _dio.get('${server.url}/api/4/network');
      return response.data as List<dynamic>?;
    } catch (e) {
      print('Ошибка получения network для ${server.name}: $e');
      return null;
    }
  }
}

