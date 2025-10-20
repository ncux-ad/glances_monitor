import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';
import '../services/glances_api_service.dart';
import '../widgets/metric_card.dart';
import '../services/storage_service.dart';
import 'network_diagnostics_screen.dart';

class ServerDetailScreen extends StatefulWidget {
  final ServerConfig server;

  const ServerDetailScreen({super.key, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> with TickerProviderStateMixin {
  final _apiService = GlancesApiService();
  SystemMetrics? _metrics;
  bool _isLoading = false;
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  late Set<String> _selectedMetrics;
  late Set<String> _selectedEndpoints;
  String _selectedNetworkInterface = 'auto';
  List<String> _availableNetworkInterfaces = [];
  late TabController _tabController;
  bool _showAdvancedOptions = false;
  Map<String, bool> _endpointsAvailability = {};
  late ScrollController _scrollController;


  @override
  void initState() {
    super.initState();
    _selectedMetrics = widget.server.selectedMetrics.toSet();
    _selectedEndpoints = widget.server.selectedEndpoints.toSet();
    _selectedNetworkInterface = widget.server.selectedNetworkInterfaces.isNotEmpty 
        ? widget.server.selectedNetworkInterfaces.first 
        : 'auto';
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _scrollController = ScrollController();
    _loadMetrics();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
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
      // Используем текущий выбор метрик при запросе
      final serverForFetch = widget.server.copyWith(
        selectedMetrics: _selectedMetrics.toList(),
        selectedEndpoints: _selectedEndpoints.toList(),
        selectedNetworkInterfaces: _selectedNetworkInterface == 'auto' 
            ? [] 
            : [_selectedNetworkInterface],
      );
      final metrics = await _apiService.fetchMetrics(serverForFetch);
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


  Future<void> _onToggleEndpoint(String ep, bool selected) async {
    // Проверяем доступность endpoint перед включением
    if (selected && _endpointsAvailability.containsKey(ep) && !_endpointsAvailability[ep]!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Endpoint "$ep" недоступен на этом сервере'),
          action: SnackBarAction(
            label: 'Обновить статус',
            onPressed: _checkEndpointsAvailability,
          ),
        ),
      );
      return;
    }

    setState(() {
      if (selected) {
        _selectedEndpoints.add(ep);
      } else {
        _selectedEndpoints.remove(ep);
      }
    });
    await StorageService.updateServer(
      widget.server.copyWith(selectedEndpoints: _selectedEndpoints.toList()),
    );
    await _loadMetrics();
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'expert_mode':
        setState(() {
          _showAdvancedOptions = !_showAdvancedOptions;
        });
        
        // При включении экспертного режима проверяем доступность endpoints
        if (_showAdvancedOptions && _endpointsAvailability.isEmpty) {
          await _checkEndpointsAvailability();
        }
        break;
    }
  }

  Future<void> _checkEndpointsAvailability() async {
    try {
      final availability = await _apiService.scanAvailableEndpoints(widget.server);
      setState(() {
        _endpointsAvailability = availability;
      });
    } catch (e) {
      // Игнорируем ошибки проверки endpoints
    }
  }

  void _showNetworkInterfaceSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбор сетевого интерфейса'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выберите сетевой интерфейс для мониторинга:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _availableNetworkInterfaces.contains(_selectedNetworkInterface) || _selectedNetworkInterface == 'auto' 
                  ? _selectedNetworkInterface 
                  : 'auto',
              decoration: const InputDecoration(
                labelText: 'Сетевой интерфейс',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'auto',
                  child: Text('Автоматически'),
                ),
                ..._availableNetworkInterfaces.toSet().map((interface) => DropdownMenuItem(
                  value: interface,
                  child: Text(interface),
                )),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedNetworkInterface = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _loadNetworkInterfaces,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _onNetworkInterfaceChanged(_selectedNetworkInterface);
              Navigator.of(context).pop();
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Future<void> _onNetworkInterfaceChanged(String? newInterface) async {
    if (newInterface == null) return;
    
    setState(() {
      _selectedNetworkInterface = newInterface;
    });
    
    await StorageService.updateServer(
      widget.server.copyWith(
        selectedNetworkInterfaces: newInterface == 'auto' 
            ? [] 
            : [newInterface],
      ),
    );
    await _loadMetrics();
  }

  Future<void> _loadNetworkInterfaces() async {
    try {
      final interfaces = await _apiService.fetchNetworkInterfaces(widget.server);
      if (mounted) {
        setState(() {
          _availableNetworkInterfaces = interfaces;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения интерфейсов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          IconButton(
            icon: const Icon(Icons.network_check),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NetworkDiagnosticsScreen(server: widget.server),
                ),
              );
            },
            tooltip: 'Диагностика сети',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'expert_mode',
                child: Row(
                  children: [
                    Icon(_showAdvancedOptions ? Icons.visibility : Icons.visibility_off),
                    const SizedBox(width: 8),
                    Text(_showAdvancedOptions ? 'Обычный режим' : 'Экспертный режим'),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            if (_showAdvancedOptions) ...[
              _buildEndpointSelector(),
              const SizedBox(height: 12),
            ],
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
                      // Отображение версии API
                      if (_metrics?.apiVersion != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.api,
                              size: 16,
                              color: _getApiVersionColor(_metrics!.apiVersion!),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'API v${_metrics!.apiVersion}',
                              style: TextStyle(
                                color: _getApiVersionColor(_metrics!.apiVersion!),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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


  Widget _buildEndpointSelector() {
    final labels = <String, String>{
      'uptime': 'Uptime',
      'system': 'System',
      'version': 'Version',
      'processcount': 'Processes',
      'percpu': 'Per-CPU',
      'load': 'Load',
      'diskio': 'Disk I/O',
      'folders': 'Folders',
      'sensors': 'Sensors',
      'smart': 'SMART',
      'raid': 'RAID',
      'docker': 'Docker',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endpoint API (дополнительно)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: labels.keys.map((ep) {
                final isAvailable = _endpointsAvailability[ep] ?? true; // По умолчанию считаем доступным
                final isSelected = _selectedEndpoints.contains(ep);
                
                return Tooltip(
                  message: isAvailable 
                    ? 'Endpoint доступен' 
                    : 'Endpoint недоступен на этом сервере',
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isAvailable ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(labels[ep]!),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: isAvailable ? (val) => _onToggleEndpoint(ep, val) : null,
                    disabledColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
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

        final selected = _selectedMetrics;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            if (selected.contains('cpu'))
              MetricCard(
                title: 'CPU',
                icon: '💻',
                value: _metrics!.cpuPercent,
                unit: '%',
                subtitle: '${_metrics!.cpuCores} ${_getCoresText(_metrics!.cpuCores)}',
              ),
            if (selected.contains('mem'))
              MetricCard(
                title: 'RAM',
                icon: '🧠',
                value: _metrics!.memPercent,
                unit: '%',
                subtitle: '${_metrics!.formatBytes(_metrics!.memUsed)}/${_metrics!.formatBytes(_metrics!.memTotal)}',
              ),
            if (selected.contains('fs'))
              MetricCard(
                title: 'Диск',
                icon: '💾',
                value: _metrics!.diskPercent,
                unit: '%',
                subtitle: '${_metrics!.formatBytes(_metrics!.diskUsed)}/${_metrics!.formatBytes(_metrics!.diskTotal)}',
              ),
            if (selected.contains('network'))
              GestureDetector(
                onTap: () => _showNetworkInterfaceSelector(),
                child: MetricCard(
                  title: 'Сеть',
                  icon: '🌐',
                  value: _metrics!.networkRxRate != null ? _metrics!.networkRxRate! : 0,
                  unit: 'KB/s',
                  subtitle: 'RX: ${_metrics!.formatBytes(_metrics!.networkRx)}\nTX: ${_metrics!.formatBytes(_metrics!.networkTx)}',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabAlignment: TabAlignment.fill,
        onTap: (index) {
          // Сбрасываем scroll position при переключении вкладок
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        },
        tabs: [
          Tab(
            icon: Icon(Icons.computer, size: 20),
            text: 'Система',
          ),
          Tab(
            icon: Icon(Icons.network_check, size: 20),
            text: 'Сеть',
          ),
          Tab(
            icon: Icon(Icons.storage, size: 20),
            text: 'Хранилище',
          ),
          Tab(
            icon: Icon(Icons.speed, size: 20),
            text: 'Производительность',
          ),
        ],
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
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
        _buildMetricTabs(),
        const SizedBox(height: 16),
        _buildTabContent(),
      ],
    );
  }

  Widget _buildTabContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: IndexedStack(
        index: _tabController.index,
        children: [
          _buildSystemTab(),
          _buildNetworkTab(),
          _buildStorageTab(),
          _buildPerformanceTab(),
        ],
      ),
    );
  }


  Widget _buildSystemTab() {
    return Column(
      children: [
        if (_metrics!.uptimeText != null) ...[
          _buildDetailedCard(
            'Uptime',
            '⏱️',
            [
              _metrics!.uptimeText!,
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_selectedMetrics.contains('mem'))
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
        if (_selectedMetrics.contains('swap') && _metrics!.swapTotal > 0) ...[
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
        if (_metrics!.systemInfo != null)
          _buildDetailedCard(
            'Система',
            '🖥️',
            [
              if (_metrics!.systemInfo!['os_name'] != null) 'OS: ${_metrics!.systemInfo!['os_name']}',
              if (_metrics!.systemInfo!['linux_distro'] != null) 'Distro: ${_metrics!.systemInfo!['linux_distro']}',
              if (_metrics!.systemInfo!['os_version'] != null) 'Kernel: ${_metrics!.systemInfo!['os_version']}',
              if (_metrics!.systemInfo!['hostname'] != null) 'Host: ${_metrics!.systemInfo!['hostname']}',
            ],
          ),
        if (_metrics!.versionInfo != null) const SizedBox(height: 12),
        if (_metrics!.versionInfo != null)
          _buildDetailedCard(
            'Версии',
            '🏷️',
            [
              ..._metrics!.versionInfo!.entries.map((e) => '${e.key}: ${e.value}'),
            ],
          ),
        if (_metrics!.processCount != null) const SizedBox(height: 12),
        if (_metrics!.processCount != null)
          _buildDetailedCard(
            'Процессы',
            '📦',
            [
              ..._metrics!.processCount!.entries.map((e) => '${e.key}: ${e.value}'),
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

  Color _getApiVersionColor(int apiVersion) {
    switch (apiVersion) {
      case 4:
        return Colors.blue; // API v4 - синий (современный)
      case 3:
        return Colors.orange; // API v3 - оранжевый (legacy)
      default:
        return Colors.grey; // Неизвестная версия - серый
    }
  }

  Widget _buildNetworkDetailedCard() {
    if (_metrics == null) return const SizedBox.shrink();
    
    final hasGaugeData = _metrics!.networkRxGauge != null || _metrics!.networkTxGauge != null;
    final hasRateData = _metrics!.networkRxRate != null || _metrics!.networkTxRate != null;
    final isApiV3 = _metrics!.apiVersion == 3;
    final isApiV4 = _metrics!.apiVersion == 4;
    
    final List<String> networkDetails = [
      'Интерфейс: ${_metrics!.networkInterface}',
    ];
    
    // Добавляем информацию о трафике в зависимости от версии API
    if (isApiV3) {
      // API v3 - показываем общий трафик и текущую скорость
      networkDetails.addAll([
        '📊 Общий RX: ${_formatBytes(_metrics!.networkRx)}',
        '📊 Общий TX: ${_formatBytes(_metrics!.networkTx)}',
      ]);
      
      // Добавляем текущую скорость если доступна
      if (_metrics!.networkRxCurrent != null && _metrics!.networkTxCurrent != null) {
        networkDetails.addAll([
          '⚡ Текущий RX: ${_formatBytes(_metrics!.networkRxCurrent!)}/сек',
          '⚡ Текущий TX: ${_formatBytes(_metrics!.networkTxCurrent!)}/сек',
        ]);
      }
      
      networkDetails.add('ℹ️ API v3: общий трафик + текущая скорость');
    } else if (isApiV4) {
      // API v4 - проверяем, есть ли FastAPI данные
      if (hasGaugeData) {
        // FastAPI - основные данные уже в networkRx/networkTx (gauge поля)
        networkDetails.addAll([
          '📊 Общий RX: ${_formatBytes(_metrics!.networkRx)}',
          '📊 Общий TX: ${_formatBytes(_metrics!.networkTx)}',
          'ℹ️ FastAPI: gauge поля как основные',
        ]);
      } else {
        // Стандартный API v4 - используем cumulative поля
        networkDetails.addAll([
          '📊 Кумулятивный RX: ${_formatBytes(_metrics!.networkRx)}',
          '📊 Кумулятивный TX: ${_formatBytes(_metrics!.networkTx)}',
          'ℹ️ API v4: поля cumulative_rx/cumulative_tx',
        ]);
      }
    } else {
      // Неизвестная версия - показываем как есть
      networkDetails.addAll([
        '📊 Получено: ${_formatBytes(_metrics!.networkRx)}',
        '📊 Отправлено: ${_formatBytes(_metrics!.networkTx)}',
      ]);
    }
    
    // Добавляем дополнительные FastAPI данные если они есть
    if (hasGaugeData && !isApiV4) {
      // Показываем gauge данные только если это не FastAPI (где они уже основные)
      networkDetails.addAll([
        '📈 Gauge RX: ${_formatBytes(_metrics!.networkRxGauge ?? 0)}',
        '📈 Gauge TX: ${_formatBytes(_metrics!.networkTxGauge ?? 0)}',
      ]);
    }
    
    if (hasRateData) {
      networkDetails.addAll([
        '⚡ Rate RX: ${_formatBytes(_metrics!.networkRxRate ?? 0)}/сек',
        '⚡ Rate TX: ${_formatBytes(_metrics!.networkTxRate ?? 0)}/сек',
      ]);
    }
    
    // Добавляем информацию о типе данных
    if (hasGaugeData || hasRateData) {
      networkDetails.add('🚀 FastAPI данные доступны');
    } else if (isApiV3) {
      networkDetails.add('📡 API v3: стандартные данные');
    } else if (isApiV4) {
      networkDetails.add('🔧 API v4: стандартные данные');
    } else {
      networkDetails.add('❓ Неизвестная версия API');
    }
    
    // Добавляем версию API если доступна
    if (_metrics!.apiVersion != null) {
      networkDetails.add('API версия: ${_metrics!.apiVersion}');
    }
    
    return _buildDetailedCard(
      'Сеть',
      '🌐',
      networkDetails,
    );
  }


  String _formatBytes(num bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    int i = 0;
    double size = bytes.toDouble();
    while (size >= k && i < sizes.length - 1) {
      size /= k;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${sizes[i]}';
  }

  Widget _buildNetworkTab() {
    if (!_selectedMetrics.contains('network')) {
      return _buildEmptyTab('Сетевые метрики не выбраны');
    }
    return _buildNetworkDetailedCard();
  }

  Widget _buildStorageTab() {
    if (!_selectedMetrics.contains('fs')) {
      return _buildEmptyTab('Метрики диска не выбраны');
    }
    return _buildDetailedCard(
      'Диск',
      '💾',
      [
        'Использовано: ${_metrics!.formatBytes(_metrics!.diskUsed)}',
        'Свободно: ${_metrics!.formatBytes(_metrics!.diskFree)}',
        'Всего: ${_metrics!.formatBytes(_metrics!.diskTotal)}',
      ],
    );
  }

  Widget _buildPerformanceTab() {
    if (!_selectedMetrics.contains('cpu')) {
      return _buildEmptyTab('Метрики CPU не выбраны');
    }
    return _buildDetailedCard(
      'CPU',
      '⚡',
      [
        'Процессор: ${_metrics!.cpuName}',
        'Частота: ${_metrics!.cpuHz} GHz',
        'Ядра: ${_metrics!.cpuCores}',
        'Загрузка: ${_metrics!.cpuPercent.toStringAsFixed(1)}%',
      ],
    );
  }

  Widget _buildEmptyTab(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
