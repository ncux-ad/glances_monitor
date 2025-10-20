import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';
import '../services/glances_api_service.dart';
import '../widgets/metric_card.dart';

class ServerDetailScreen extends StatefulWidget {
  final ServerConfig server;

  const ServerDetailScreen({super.key, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  final _apiService = GlancesApiService();
  SystemMetrics? _metrics;
  bool _isLoading = false;
  Timer? _refreshTimer;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          _loadMetrics();
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadMetrics() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final metrics = await _apiService.fetchMetrics(widget.server);
      if (mounted) {
        setState(() {
          _metrics = metrics;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки метрик: $e'),
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

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });

    if (_autoRefresh) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.server.flag} ${widget.server.name}'),
        actions: [
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoRefresh,
            tooltip: _autoRefresh ? 'Остановить автообновление' : 'Запустить автообновление',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMetrics,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _metrics == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_metrics == null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServerInfo(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 16),
            _buildDetailedMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final errorMessage = _metrics?.errorMessage ?? 'Загрузка данных...';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Не удалось подключиться к серверу',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ошибка: $errorMessage',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo() {
    final theme = Theme.of(context);
    final isOnline = _metrics?.isOnline ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.server.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.server.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.server.url,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isOnline ? 'Онлайн' : 'Офлайн',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_metrics != null && _metrics!.isOnline) ...[
              const SizedBox(height: 12),
              Text(
                'CPU: ${_metrics!.cpuName}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                'Частота: ${(_metrics!.cpuHz / 1000000000).toStringAsFixed(2)} GHz',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                'Ядра: ${_metrics!.cpuCores}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    if (_metrics == null || !_metrics!.isOnline) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
          childAspectRatio = 1.2;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.3;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 1.2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            MetricCard(
              title: 'CPU',
              icon: '💻',
              value: _metrics!.cpuPercent,
              unit: '%',
              subtitle: '${_metrics!.cpuCores} ${_getCoresText(_metrics!.cpuCores)}',
            ),
            MetricCard(
              title: 'RAM',
              icon: '🧠',
              value: _metrics!.memPercent,
              unit: '%',
              subtitle: '${_metrics!.formatBytes(_metrics!.memUsed)}/${_metrics!.formatBytes(_metrics!.memTotal)}',
            ),
            MetricCard(
              title: 'Диск',
              icon: '💾',
              value: _metrics!.diskPercent,
              unit: '%',
              subtitle: '${_metrics!.formatBytes(_metrics!.diskUsed)}/${_metrics!.formatBytes(_metrics!.diskTotal)}',
            ),
            MetricCard(
              title: 'Сеть',
              icon: '🌐',
              value: 0,
              unit: '',
              subtitle: _metrics!.networkInterface,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailedMetrics() {
    if (_metrics == null || !_metrics!.isOnline) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Детальная информация',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailedCard(
          'Память',
          '🧠',
          [
            'Использовано: ${_metrics!.formatBytes(_metrics!.memUsed)}',
            'Свободно: ${_metrics!.formatBytes(_metrics!.memFree)}',
            'Всего: ${_metrics!.formatBytes(_metrics!.memTotal)}',
          ],
        ),
        const SizedBox(height: 12),
        if (_metrics!.swapTotal > 0) ...[
          _buildDetailedCard(
            'Swap',
            '🔄',
            [
              'Использовано: ${_metrics!.formatBytes(_metrics!.swapUsed)}',
              'Свободно: ${_metrics!.formatBytes(_metrics!.swapFree)}',
              'Всего: ${_metrics!.formatBytes(_metrics!.swapTotal)}',
            ],
          ),
          const SizedBox(height: 12),
        ],
        _buildDetailedCard(
          'Диск',
          '💾',
          [
            'Использовано: ${_metrics!.formatBytes(_metrics!.diskUsed)}',
            'Свободно: ${_metrics!.formatBytes(_metrics!.diskFree)}',
            'Всего: ${_metrics!.formatBytes(_metrics!.diskTotal)}',
          ],
        ),
        const SizedBox(height: 12),
        _buildDetailedCard(
          'Сеть',
          '🌐',
          [
            'Интерфейс: ${_metrics!.networkInterface}',
            'Получено: ${_metrics!.formatBytes(_metrics!.networkRx)}',
            'Отправлено: ${_metrics!.formatBytes(_metrics!.networkTx)}',
          ],
        ),
      ],
    );
  }

  String _getCoresText(int cores) {
    if (cores == 1) return 'ядро';
    if (cores >= 2 && cores <= 4) return 'ядра';
    return 'ядер';
  }

  Widget _buildDetailedCard(String title, String icon, List<String> details) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            ...details.map((detail) => Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            )),
          ],
        ),
      ),
    );
  }
}
