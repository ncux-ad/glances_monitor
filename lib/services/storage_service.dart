import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';

class StorageService {
  static const String _serversKey = 'servers';

  static Future<List<ServerConfig>> loadServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = prefs.getStringList(_serversKey) ?? [];
      
      return serversJson
          .map((json) => ServerConfig.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('Ошибка загрузки серверов: $e');
      return [];
    }
  }

  static Future<bool> saveServers(List<ServerConfig> servers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = servers
          .map((server) => jsonEncode(server.toJson()))
          .toList();
      
      return await prefs.setStringList(_serversKey, serversJson);
    } catch (e) {
      print('Ошибка сохранения серверов: $e');
      return false;
    }
  }

  static Future<bool> addServer(ServerConfig server) async {
    try {
      final servers = await loadServers();
      servers.add(server);
      return await saveServers(servers);
    } catch (e) {
      print('Ошибка добавления сервера: $e');
      return false;
    }
  }

  static Future<bool> updateServer(ServerConfig server) async {
    try {
      final servers = await loadServers();
      final index = servers.indexWhere((s) => s.id == server.id);
      
      if (index != -1) {
        servers[index] = server;
        return await saveServers(servers);
      }
      return false;
    } catch (e) {
      print('Ошибка обновления сервера: $e');
      return false;
    }
  }

  static Future<bool> deleteServer(String serverId) async {
    try {
      final servers = await loadServers();
      servers.removeWhere((server) => server.id == serverId);
      return await saveServers(servers);
    } catch (e) {
      print('Ошибка удаления сервера: $e');
      return false;
    }
  }

  static Future<ServerConfig?> getServer(String serverId) async {
    try {
      final servers = await loadServers();
      return servers.firstWhere(
        (server) => server.id == serverId,
        orElse: () => throw Exception('Сервер не найден'),
      );
    } catch (e) {
      print('Ошибка получения сервера: $e');
      return null;
    }
  }
}

