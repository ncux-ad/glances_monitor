import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/server_config.dart';
import '../services/endpoint_diagnostics.dart';
import '../services/network_log_generator.dart';

class EndpointDiagnosticsScreen extends StatefulWidget {
  final ServerConfig server;

  const EndpointDiagnosticsScreen({super.key, required this.server});

  @override
  State<EndpointDiagnosticsScreen> createState() => _EndpointDiagnosticsScreenState();
}

class _EndpointDiagnosticsScreenState extends State<EndpointDiagnosticsScreen> {
  final _diagnostics = EndpointDiagnostics();
  Map<String, dynamic>? _diagnosticResults;
  bool _isLoading = false;
  String? _selectedEndpoint;
  String? _additionalNotes;

  @override
  void initState() {
    super.initState();
    _runFullDiagnostics();
  }

  Future<void> _runFullDiagnostics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _diagnostics.testAllEndpoints(widget.server);
      if (mounted) {
        setState(() {
          _diagnosticResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка диагностики: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testSingleEndpoint(String endpoint) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _diagnostics.diagnoseEndpoint(widget.server, endpoint);
      if (mounted) {
        setState(() {
          _diagnosticResults?[endpoint] = result;
          _selectedEndpoint = endpoint;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка тестирования $endpoint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Диагностика Endpoint - ${widget.server.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportLog,
            tooltip: 'Экспорт лога',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runFullDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDiagnosticsContent(),
    );
  }

  Widget _buildDiagnosticsContent() {
    if (_diagnosticResults == null) {
      return const Center(
        child: Text('Ошибка загрузки диагностики'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildEndpointList(),
          if (_selectedEndpoint != null) ...[
            const SizedBox(height: 16),
            _buildDetailedEndpointCard(_selectedEndpoint!),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final results = _diagnosticResults!;
    final available = results.values.where((r) => r['is_available'] == true).length;
    final total = results.length;
    final issues = results.values.where((r) => (r['issues'] as List).isNotEmpty).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  issues == 0 ? Icons.check_circle : Icons.warning,
                  color: issues == 0 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Сводка диагностики',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Сервер: ${widget.server.url}'),
            Text('Доступно endpoint: $available из $total'),
            Text('Проблем обнаружено: $issues'),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointList() {
    final results = _diagnosticResults!;
    final endpointLabels = {
      'quicklook': 'Обзор',
      'mem': 'Память',
      'memswap': 'Swap',
      'fs': 'Файловая система',
      'cpu': 'CPU',
      'network': 'Сеть',
      'uptime': 'Время работы',
      'system': 'Система',
      'version': 'Версии',
      'processcount': 'Счетчик процессов',
      'processlist': 'Список процессов',
      'sensors': 'Датчики',
      'smart': 'SMART',
      'raid': 'RAID',
      'docker': 'Docker',
      'wifi': 'Wi-Fi',
      'load': 'Нагрузка',
      'alert': 'Оповещения',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endpoint статус',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...results.entries.map((entry) => _buildEndpointTile(entry.key, entry.value, endpointLabels[entry.key] ?? entry.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointTile(String endpoint, Map<String, dynamic> result, String label) {
    final isAvailable = result['is_available'] as bool? ?? false;
    final issues = result['issues'] as List<dynamic>? ?? [];
    final responseTime = result['response_time_ms'] as int?;
    final statusCode = result['status_code'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isAvailable ? Icons.check_circle : Icons.error,
          color: isAvailable ? Colors.green : Colors.red,
        ),
        title: Text(label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Endpoint: $endpoint'),
            if (responseTime != null) Text('Время ответа: ${responseTime}ms'),
            if (statusCode != null) Text('HTTP код: $statusCode'),
            if (issues.isNotEmpty) Text('Проблемы: ${issues.length}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (issues.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showIssuesDialog(endpoint, issues),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _testSingleEndpoint(endpoint),
            ),
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => setState(() => _selectedEndpoint = endpoint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedEndpointCard(String endpoint) {
    final result = _diagnosticResults![endpoint];
    if (result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Детальная информация',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedEndpoint = null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Endpoint: $endpoint'),
            Text('Статус: ${result['is_available'] == true ? 'Доступен' : 'Недоступен'}'),
            if (result['api_version'] != null) Text('API версия: ${result['api_version']}'),
            if (result['response_time_ms'] != null) Text('Время ответа: ${result['response_time_ms']}ms'),
            if (result['status_code'] != null) Text('HTTP код: ${result['status_code']}'),
            if (result['data_size_bytes'] != null) Text('Размер данных: ${result['data_size_bytes']} байт'),
            if (result['error_message'] != null) Text('Ошибка: ${result['error_message']}'),
            
            const SizedBox(height: 12),
            if ((result['issues'] as List).isNotEmpty) ...[
              const Text('Проблемы:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(result['issues'] as List).map((issue) => Text('• $issue')),
            ],
            
            const SizedBox(height: 12),
            if ((result['recommendations'] as List).isNotEmpty) ...[
              const Text('Рекомендации:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(result['recommendations'] as List).map((rec) => Text('• $rec')),
            ],
            
            const SizedBox(height: 12),
            if (result['raw_data'] != null) ...[
              const Text('Сырые данные:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result['raw_data'].toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showIssuesDialog(String endpoint, List<dynamic> issues) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Проблемы с $endpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: issues.map((issue) => Text('• $issue')).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _exportLog() {
    if (_diagnosticResults == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных для экспорта'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Экспорт диагностического лога',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Копировать в буфер обмена'),
                onTap: () {
                  final log = NetworkLogGenerator.generateEndpointDiagnosticLog(
                    diagnosticResults: _diagnosticResults!,
                    server: widget.server,
                    additionalNotes: _additionalNotes,
                  );
                  Clipboard.setData(ClipboardData(text: log));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Лог скопирован в буфер обмена')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Поделиться'),
                onTap: () {
                  final log = NetworkLogGenerator.generateEndpointDiagnosticLog(
                    diagnosticResults: _diagnosticResults!,
                    server: widget.server,
                    additionalNotes: _additionalNotes,
                  );
                  Share.share(
                    log,
                    subject: 'Диагностика Endpoint - ${widget.server.name}',
                  );
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Сохранить как файл'),
                onTap: () {
                  final log = NetworkLogGenerator.generateEndpointDiagnosticLog(
                    diagnosticResults: _diagnosticResults!,
                    server: widget.server,
                    additionalNotes: _additionalNotes,
                  );
                  final fileName = 'endpoint_diagnostics_${widget.server.name}_${DateTime.now().millisecondsSinceEpoch}.txt';
                  Share.shareXFiles(
                    [XFile.fromData(Uint8List.fromList(log.codeUnits), name: fileName, mimeType: 'text/plain')],
                    subject: 'Диагностика Endpoint - ${widget.server.name}',
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
