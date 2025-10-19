class ServerConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String flag;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.flag,
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
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      flag: flag ?? this.flag,
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
    return 'ServerConfig(id: $id, name: $name, host: $host, port: $port, username: $username, flag: $flag)';
  }
}

