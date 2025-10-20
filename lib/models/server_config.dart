class ServerConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String flag;
  // Набор выбранных метрик для отображения (cpu, mem, fs, network, swap)
  final List<String> selectedMetrics;
  // Набор выбранных endpoint API Glances (напр. quicklook, mem, fs, cpu, network, uptime, system, processlist, sensors, ...)
  final List<String> selectedEndpoints;
  // Предпочитаемые сетевые интерфейсы для отображения (если пусто — авто)
  final List<String> selectedNetworkInterfaces;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.flag,
    this.selectedMetrics = const ['cpu', 'mem', 'fs', 'network', 'swap'],
    this.selectedEndpoints = const ['quicklook','mem','memswap','fs','cpu','network','uptime','system'],
    this.selectedNetworkInterfaces = const [],
  });

  // Геттер для полного URL
  String get url => 'http://$host:$port';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'flag': flag,
      'selectedMetrics': selectedMetrics,
      'selectedEndpoints': selectedEndpoints,
      'selectedNetworkInterfaces': selectedNetworkInterfaces,
    };
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      flag: json['flag'] as String,
      selectedMetrics: (json['selectedMetrics'] as List?)?.map((e) => e.toString()).toList() ?? const ['cpu', 'mem', 'fs', 'network', 'swap'],
      selectedEndpoints: (json['selectedEndpoints'] as List?)?.map((e) => e.toString()).toList() ?? const ['quicklook','mem','memswap','fs','cpu','network','uptime','system'],
      selectedNetworkInterfaces: (json['selectedNetworkInterfaces'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  ServerConfig copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? flag,
    List<String>? selectedMetrics,
    List<String>? selectedEndpoints,
    List<String>? selectedNetworkInterfaces,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      flag: flag ?? this.flag,
      selectedMetrics: selectedMetrics ?? this.selectedMetrics,
      selectedEndpoints: selectedEndpoints ?? this.selectedEndpoints,
      selectedNetworkInterfaces: selectedNetworkInterfaces ?? this.selectedNetworkInterfaces,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServerConfig(id: $id, name: $name, host: $host, port: $port, username: $username, flag: $flag, selectedMetrics: $selectedMetrics, selectedEndpoints: $selectedEndpoints, selectedNetworkInterfaces: $selectedNetworkInterfaces)';
  }
}

