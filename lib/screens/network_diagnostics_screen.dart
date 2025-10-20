import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/server_config.dart';
import '../services/network_diagnostics.dart';
import '../services/network_log_generator.dart';

class NetworkDiagnosticsScreen extends StatefulWidget {
  final ServerConfig server;

  const NetworkDiagnosticsScreen({super.key, required this.server});

  @override
  State<NetworkDiagnosticsScreen> createState() => _NetworkDiagnosticsScreenState();
}

class _NetworkDiagnosticsScreenState extends State<NetworkDiagnosticsScreen> {
  final _diagnostics = NetworkDiagnostics();
  Map<String, dynamic>? _diagnosticData;
  Map<String, dynamic>? _activityTest;
  bool _isLoading = false;
  String? _additionalNotes;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final diagnostics = await _diagnostics.diagnoseNetwork(widget.server);
      final activity = await _diagnostics.testNetworkActivity(widget.server);
      
      if (mounted) {
        setState(() {
          _diagnosticData = diagnostics;
          _activityTest = activity;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Диагностика сети - ${widget.server.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportLog,
            tooltip: 'Экспорт лога',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDiagnosticsContent(),
    );
  }

  Widget _buildDiagnosticsContent() {
    if (_diagnosticData == null) {
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
            _buildNotesCard(),
            const SizedBox(height: 16),
            _buildIssuesCard(),
          const SizedBox(height: 16),
          _buildInterfacesCard(),
          const SizedBox(height: 16),
          _buildActivityTestCard(),
          const SizedBox(height: 16),
          _buildRecommendationsCard(),
          const SizedBox(height: 16),
          _buildRawDataCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final issues = _diagnosticData!['issues'] as List<dynamic>;
    final interfaces = _diagnosticData!['interfaces'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  issues.isEmpty ? Icons.check_circle : Icons.warning,
                  color: issues.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Сводка диагностики',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Сервер: ${_diagnosticData!['server']}'),
            Text('API версия: ${_diagnosticData!['api_version']}'),
            Text('Интерфейсов найдено: ${interfaces.length}'),
            Text('Проблем обнаружено: ${issues.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesCard() {
    final issues = _diagnosticData!['issues'] as List<dynamic>;
    
    if (issues.isEmpty) {
      return Card(
        color: Colors.green.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Проблем не обнаружено'),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Обнаруженные проблемы',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $issue'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfacesCard() {
    final interfaces = _diagnosticData!['interfaces'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сетевые интерфейсы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...interfaces.map((iface) => _buildInterfaceTile(iface)),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfaceTile(Map<String, dynamic> iface) {
    final name = iface['name'] as String;
    final isUp = iface['is_up'] as bool;
    final cumulativeRx = iface['cumulative_rx'] as num;
    final cumulativeTx = iface['cumulative_tx'] as num;
    final rxPerSec = iface['rx_bytes_per_sec'] as num;
    final txPerSec = iface['tx_bytes_per_sec'] as num;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUp ? Icons.check_circle : Icons.cancel,
                  color: isUp ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  isUp ? 'Активен' : 'Неактивен',
                  style: TextStyle(
                    color: isUp ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Кумулятивный RX: ${_formatBytes(cumulativeRx)}'),
            Text('Кумулятивный TX: ${_formatBytes(cumulativeTx)}'),
            Text('Скорость RX: ${_formatBytes(rxPerSec)}/сек'),
            Text('Скорость TX: ${_formatBytes(txPerSec)}/сек'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTestCard() {
    if (_activityTest == null) return const SizedBox.shrink();
    
    final testResults = _activityTest!['test_results'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Тест активности (2 секунды)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...testResults.map((result) => _buildActivityResult(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityResult(Map<String, dynamic> result) {
    final interface = result['interface'] as String;
    final rxChange = result['rx_change'] as num;
    final txChange = result['tx_change'] as num;
    final hasActivity = result['has_activity'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              hasActivity ? Icons.trending_up : Icons.trending_flat,
              color: hasActivity ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interface,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('RX: ${_formatBytes(rxChange)}'),
                  Text('TX: ${_formatBytes(txChange)}'),
                ],
              ),
            ),
            Text(
              hasActivity ? 'Активен' : 'Нет активности',
              style: TextStyle(
                color: hasActivity ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations = _diagnosticData!['recommendations'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Рекомендации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $rec'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сырые данные',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _diagnosticData!['raw_network_data'].toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Дополнительные заметки',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _editNotes,
                  tooltip: 'Редактировать заметки',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _additionalNotes?.isNotEmpty == true 
                  ? _additionalNotes! 
                  : 'Нажмите "Редактировать заметки" чтобы добавить дополнительную информацию для лога',
              style: TextStyle(
                color: _additionalNotes?.isNotEmpty == true 
                    ? null 
                    : Colors.grey[600],
                fontStyle: _additionalNotes?.isNotEmpty == true 
                    ? FontStyle.normal 
                    : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editNotes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дополнительные заметки'),
        content: TextField(
          controller: TextEditingController(text: _additionalNotes ?? ''),
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Добавьте дополнительную информацию о проблеме...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _additionalNotes = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.of(context).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _exportLog() {
    if (_diagnosticData == null) {
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
                  final log = NetworkLogGenerator.generateNetworkDiagnosticLog(
                    diagnosticData: _diagnosticData!,
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
                  final log = NetworkLogGenerator.generateNetworkDiagnosticLog(
                    diagnosticData: _diagnosticData!,
                    server: widget.server,
                    additionalNotes: _additionalNotes,
                  );
                  Share.share(
                    log,
                    subject: 'Диагностика сети - ${widget.server.name}',
                  );
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Сохранить как файл'),
                onTap: () {
                  final log = NetworkLogGenerator.generateNetworkDiagnosticLog(
                    diagnosticData: _diagnosticData!,
                    server: widget.server,
                    additionalNotes: _additionalNotes,
                  );
                  final fileName = 'network_diagnostics_${widget.server.name}_${DateTime.now().millisecondsSinceEpoch}.txt';
                  Share.shareXFiles(
                    [XFile.fromData(Uint8List.fromList(log.codeUnits), name: fileName, mimeType: 'text/plain')],
                    subject: 'Диагностика сети - ${widget.server.name}',
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

  String _formatBytes(num bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    final i = (bytes / k).floor();
    final clampedIndex = i < sizes.length ? i : sizes.length - 1;
    return '${(bytes / (k * clampedIndex)).toStringAsFixed(1)} ${sizes[clampedIndex]}';
  }
}
