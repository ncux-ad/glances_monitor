import 'package:flutter/services.dart';
import 'build_info_data.dart';

class BuildInfo {
  /// Получить версию приложения
  static Future<String> getVersion() async {
    try {
      const platform = MethodChannel('build_info');
      return await platform.invokeMethod('getVersion');
    } catch (e) {
      return BuildInfoData.version;
    }
  }

  /// Получить номер сборки
  static Future<String> getBuildNumber() async {
    try {
      const platform = MethodChannel('build_info');
      return await platform.invokeMethod('getBuildNumber');
    } catch (e) {
      return BuildInfoData.buildNumber;
    }
  }

  /// Получить хеш коммита
  static Future<String> getCommitHash() async {
    try {
      const platform = MethodChannel('build_info');
      return await platform.invokeMethod('getCommitHash');
    } catch (e) {
      return BuildInfoData.commitHash;
    }
  }

  /// Получить дату сборки
  static Future<String> getBuildDate() async {
    try {
      const platform = MethodChannel('build_info');
      return await platform.invokeMethod('getBuildDate');
    } catch (e) {
      return BuildInfoData.buildDate;
    }
  }

  /// Получить полную информацию о сборке
  static Future<Map<String, String>> getFullBuildInfo() async {
    return {
      'version': await getVersion(),
      'buildNumber': await getBuildNumber(),
      'commitHash': await getCommitHash(),
      'buildDate': await getBuildDate(),
    };
  }

  /// Получить короткий хеш коммита (первые 7 символов)
  static Future<String> getShortCommitHash() async {
    final hash = await getCommitHash();
    return hash.length > 7 ? hash.substring(0, 7) : hash;
  }

  /// Получить информацию о сборке в читаемом формате
  static Future<String> getBuildInfoString() async {
    final info = await getFullBuildInfo();
    return 'v${info['version']} (${info['buildNumber']}) - ${info['commitHash']}';
  }

  /// Получить статическую информацию о сборке (без async)
  static Map<String, String> getStaticBuildInfo() {
    return {
      'version': BuildInfoData.version,
      'buildNumber': BuildInfoData.buildNumber,
      'commitHash': BuildInfoData.commitHash,
      'buildDate': BuildInfoData.buildDate,
    };
  }
}
