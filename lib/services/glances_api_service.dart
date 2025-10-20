import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';

class GlancesApiService {
  static const int timeoutSeconds = 5;
  late final Dio _dio;
  int _apiVersion = 4; // По умолчанию v4

  GlancesApiService() {
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

  Future<void> _determineApiVersion(ServerConfig server) async {
    try {
      // Пробуем сначала v4
      await _dio.get('${server.url}/api/4/now');
      _apiVersion = 4;
    } catch (e) {
      // Если v4 недоступна, пробуем v3
      try {
        await _dio.get('${server.url}/api/3/now');
        _apiVersion = 3;
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
      await _determineApiVersion(server);

      final apiUrl = '${server.url}/api/$_apiVersion';

      final responses = await Future.wait([
        _dio.get('$apiUrl/quicklook'),
        _dio.get('$apiUrl/mem'),
        _dio.get('$apiUrl/memswap'),
        _dio.get('$apiUrl/fs'),
        _dio.get('$apiUrl/cpu'),
        _dio.get('$apiUrl/network'),
      ]);

      return SystemMetrics.fromGlancesData(
        quicklook: responses[0].data as Map<String, dynamic>,
        memory: responses[1].data as Map<String, dynamic>,
        memswap: responses[2].data as Map<String, dynamic>,
        disk: responses[3].data as List<dynamic>,
        cpu: responses[4].data as Map<String, dynamic>,
        network: responses[5].data as List<dynamic>,
        apiVersion: _apiVersion,
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
      await _determineApiVersion(server);
      final response = await _dio.get('${server.url}/api/$_apiVersion/now');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
