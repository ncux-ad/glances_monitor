import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/server_config.dart';
import '../services/connection_options.dart';

class ConnectionOptionsScreen extends StatefulWidget {
  final ServerConfig server;

  const ConnectionOptionsScreen({super.key, required this.server});

  @override
  State<ConnectionOptionsScreen> createState() => _ConnectionOptionsScreenState();
}

class _ConnectionOptionsScreenState extends State<ConnectionOptionsScreen> {
  String? _selectedOption;
  final List<Map<String, dynamic>> _recommendedOptions = [];

  @override
  void initState() {
    super.initState();
    _recommendedOptions.addAll(ConnectionOptions.getRecommendedOptions(widget.server));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Варианты подключения - ${widget.server.name}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServerInfo(),
            const SizedBox(height: 16),
            _buildRecommendedOptions(),
            const SizedBox(height: 16),
            _buildAllOptions(),
            if (_selectedOption != null) ...[
              const SizedBox(height: 16),
              _buildSelectedOptionDetails(),
            ],
            const SizedBox(height: 16),
            _buildTroubleshooting(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о сервере',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Хост: ${widget.server.host}'),
            Text('Порт: ${widget.server.port}'),
            Text('Аутентификация: ${widget.server.username.isNotEmpty ? "Настроена" : "Не настроена"}'),
            if (widget.server.username.isNotEmpty) Text('Пользователь: ${widget.server.username}'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Рекомендуемые варианты',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._recommendedOptions.map((option) => _buildOptionTile(option, isRecommended: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Все варианты подключения',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...ConnectionOptions.connectionTypes.map((option) => _buildOptionTile(option)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(Map<String, dynamic> option, {bool isRecommended = false}) {
    final isSelected = _selectedOption == option['id'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Text(
          option['icon'],
          style: const TextStyle(fontSize: 24),
        ),
        title: Row(
          children: [
            Text(option['name']),
            if (isRecommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Рекомендуется',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(option['description']),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
        onTap: () => setState(() => _selectedOption = option['id']),
      ),
    );
  }

  Widget _buildSelectedOptionDetails() {
    final option = ConnectionOptions.getConnectionType(_selectedOption!);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  option['icon'],
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option['name'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(option['description']),
            
            const SizedBox(height: 16),
            _buildProsCons(option),
            
            const SizedBox(height: 16),
            _buildSetupSteps(option),
            
            const SizedBox(height: 16),
            _buildActionButtons(option),
          ],
        ),
      ),
    );
  }

  Widget _buildProsCons(Map<String, dynamic> option) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Преимущества:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(option['pros'] as List).map((pro) => Text('• $pro')),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Недостатки:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(option['cons'] as List).map((con) => Text('• $con')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupSteps(Map<String, dynamic> option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Настройка:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...(option['setup'] as List).asMap().entries.map((entry) {
          final index = entry.key + 1;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('$index. $step'),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Полезные команды:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        if (option['id'] == 'nginx_proxy') ...[
          _buildCopyButton('Конфигурация Nginx', ConnectionOptions.generateNginxConfig(widget.server)),
        ],
        
        if (option['id'] == 'ssh_tunnel') ...[
          _buildCopyButton('SSH команда', ConnectionOptions.generateSSHCommand(widget.server)),
        ],
        
        _buildCopyButton('Тест подключения', ConnectionOptions.generateCurlTest(widget.server)),
      ],
    );
  }

  Widget _buildCopyButton(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              // Информация скопирована в буфер обмена
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshooting() {
    final steps = ConnectionOptions.getTroubleshootingSteps(widget.server);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Диагностика проблем',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Если подключение не работает, выполните следующие шаги:'),
            const SizedBox(height: 8),
            ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $step'),
            )),
          ],
        ),
      ),
    );
  }
}
