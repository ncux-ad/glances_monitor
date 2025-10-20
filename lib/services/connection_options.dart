import '../models/server_config.dart';

class ConnectionOptions {
  static const List<Map<String, dynamic>> connectionTypes = [
    {
      'id': 'direct',
      'name': 'Прямое подключение',
      'description': 'Прямое подключение к Glances API',
      'icon': '🔗',
      'pros': ['Быстро', 'Просто', 'Минимум настроек'],
      'cons': ['Требует открытый порт', 'Нет шифрования'],
      'setup': [
        'Убедитесь что Glances запущен: glances -w --port 61208',
        'Проверьте доступность: curl http://server:61208/api/4/now',
        'Настройте Basic Auth если нужно: glances -w --port 61208 --username glances --password your_password'
      ]
    },
    {
      'id': 'nginx_proxy',
      'name': 'Nginx Reverse Proxy',
      'description': 'Через Nginx с Basic Auth',
      'icon': '🛡️',
      'pros': ['Безопасность', 'SSL/TLS', 'Логирование', 'Кэширование'],
      'cons': ['Сложная настройка', 'Дополнительные зависимости'],
      'setup': [
        'Установите Nginx: sudo apt install nginx',
        'Создайте конфигурацию: /etc/nginx/sites-available/glances',
        'Настройте Basic Auth: sudo htpasswd -c /etc/nginx/.htpasswd glances',
        'Перезапустите Nginx: sudo systemctl restart nginx'
      ]
    },
    {
      'id': 'ssh_tunnel',
      'name': 'SSH Туннель',
      'description': 'SSH туннель для безопасного подключения',
      'icon': '🔒',
      'pros': ['Безопасность', 'Шифрование', 'Не нужен открытый порт'],
      'cons': ['Требует SSH доступ', 'Сложная настройка'],
      'setup': [
        'Настройте SSH ключи: ssh-keygen -t rsa',
        'Скопируйте ключ на сервер: ssh-copy-id user@server',
        'Создайте туннель: ssh -L 61209:localhost:61208 user@server',
        'Подключитесь к localhost:61209'
      ]
    },
    {
      'id': 'vpn',
      'name': 'VPN подключение',
      'description': 'Через VPN (WireGuard/OpenVPN)',
      'icon': '🌐',
      'pros': ['Полная безопасность', 'Доступ к внутренней сети'],
      'cons': ['Сложная настройка VPN', 'Требует VPN сервер'],
      'setup': [
        'Настройте VPN сервер (WireGuard/OpenVPN)',
        'Подключитесь к VPN',
        'Используйте внутренний IP сервера',
        'Настройте маршрутизацию если нужно'
      ]
    }
  ];

  static Map<String, dynamic> getConnectionType(String id) {
    return connectionTypes.firstWhere(
      (type) => type['id'] == id,
      orElse: () => connectionTypes.first,
    );
  }

  static List<Map<String, dynamic>> getRecommendedOptions(ServerConfig server) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Анализируем текущую конфигурацию сервера
    final hasAuth = server.username.isNotEmpty && server.password.isNotEmpty;
    final isLocalhost = server.host == 'localhost' || server.host == '127.0.0.1';
    
    // Рекомендации на основе конфигурации
    if (isLocalhost) {
      recommendations.add(getConnectionType('direct'));
    } else if (hasAuth) {
      recommendations.add(getConnectionType('nginx_proxy'));
    } else {
      recommendations.add(getConnectionType('ssh_tunnel'));
    }
    
    // Добавляем альтернативные варианты
    for (final type in connectionTypes) {
      if (!recommendations.any((rec) => rec['id'] == type['id'])) {
        recommendations.add(type);
      }
    }
    
    return recommendations;
  }

  static String generateNginxConfig(ServerConfig server) {
    return '''
# /etc/nginx/sites-available/glances
server {
    listen ${server.port};
    server_name ${server.host};
    
    # Basic Auth
    auth_basic "Glances API";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    # CORS headers
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
    add_header Access-Control-Allow-Headers "Authorization, Content-Type";
    
    location / {
        proxy_pass http://localhost:61209;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
''';
  }

  static String generateSSHCommand(ServerConfig server) {
    return 'ssh -L 61209:localhost:61208 ${server.username}@${server.host}';
  }

  static String generateCurlTest(ServerConfig server) {
    if (server.username.isNotEmpty && server.password.isNotEmpty) {
      return 'curl -u ${server.username}:${server.password} http://${server.host}:${server.port}/api/4/now';
    } else {
      return 'curl http://${server.host}:${server.port}/api/4/now';
    }
  }

  static List<String> getTroubleshootingSteps(ServerConfig server) {
    return [
      'Проверьте что Glances запущен: ps aux | grep glances',
      'Проверьте порт: netstat -tlnp | grep ${server.port}',
      'Проверьте подключение: ${generateCurlTest(server)}',
      'Проверьте логи Glances: journalctl -u glances -f',
      'Проверьте права доступа: sudo -u glances glances --version',
      'Проверьте конфигурацию: glances --export json | head -20',
    ];
  }
}
