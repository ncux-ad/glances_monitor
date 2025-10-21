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
  int _contentUpdateCounter = 0;


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
    
    // Добавляем слушатель изменений TabController
    _tabController.addListener(_onTabChanged);
    
    _loadMetrics();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      // Сбрасываем scroll position при переключении вкладок
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      // Увеличиваем счетчик для принудительного обновления контента
      _contentUpdateCounter++;
      // Принудительно обновляем состояние для перерисовки контента
      setState(() {});
    }
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
        
        
        // Обновляем данные без показа уведомлений
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
      return; // Просто не включаем недоступный endpoint
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
    
    // Обновляем данные без показа уведомлений
    
    
    
    await _loadMetrics();
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'network_diagnostics':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NetworkDiagnosticsScreen(server: widget.server),
          ),
        );
        break;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка проверки endpoints: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              initialValue: _getValidDropdownValue(),
              decoration: const InputDecoration(
                labelText: 'Сетевой интерфейс',
                border: OutlineInputBorder(),
              ),
              items: _buildDropdownItems(),
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
          // Убираем дубликаты и пустые строки
          _availableNetworkInterfaces = interfaces
              .where((interface) => interface.isNotEmpty)
              .toSet()
              .toList();
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
        title: Text(
          '${widget.server.flag} ${widget.server.name}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Основные кнопки - только самые важные
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoRefresh,
            tooltip: _autoRefresh ? 'Остановить автообновление' : 'Запустить автообновление',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMetrics,
            tooltip: 'Обновить данные',
          ),
          // Все остальные функции в меню
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'network_diagnostics',
                child: Row(
                  children: [
                    const Icon(Icons.network_check),
                    const SizedBox(width: 8),
                    const Text('Диагностика сети'),
                  ],
                ),
              ),
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
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildDetailedMetrics(),
            ),
          ),
        ],
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
    // Используем полный список endpoints как в экране добавления сервера
    final endpoints = GlancesApiService.knownEndpoints;
    
    // Создаем читаемые названия для endpoints
    final labels = <String, String>{
      'quicklook': 'Quick Look',
      'mem': 'Memory',
      'memswap': 'Swap',
      'fs': 'File System',
      'cpu': 'CPU',
      'network': 'Network',
      'percpu': 'Per-CPU',
      'load': 'Load',
      'uptime': 'Uptime',
      'system': 'System',
      'version': 'Version',
      'processcount': 'Processes',
      'processlist': 'Process List',
      'sensors': 'Sensors',
      'smart': 'SMART',
      'raid': 'RAID',
      'docker': 'Docker',
      'gpu': 'GPU',
      'diskio': 'Disk I/O',
      'folders': 'Folders',
      'wifi': 'WiFi',
      'alert': 'Alerts',
      'connections': 'Connections',
      'containers': 'Containers',
      'ports': 'Ports',
      'vms': 'VMs',
      'amps': 'AMP',
      'cloud': 'Cloud',
      'ip': 'IP',
      'irq': 'IRQ',
      'programlist': 'Programs',
      'psutilversion': 'psutil',
      'help': 'Help',
      'core': 'Core',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Адаптивный заголовок с кнопкой и счетчиком
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  // Для узких экранов - вертикальный layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Endpoint API (дополнительно)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (_selectedEndpoints.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedEndpoints.length} активных',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _checkEndpointsAvailability,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Проверить доступность'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Для широких экранов - горизонтальный layout
                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              'Endpoint API (дополнительно)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            if (_selectedEndpoints.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_selectedEndpoints.length} активных',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _checkEndpointsAvailability,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Проверить'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            // Компактный Wrap для всех размеров экрана
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: endpoints.map((ep) {
                final isAvailable = _endpointsAvailability[ep] ?? true;
                final isSelected = _selectedEndpoints.contains(ep);
                final displayName = labels[ep] ?? ep; // Используем читаемое название или сам endpoint
                
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
                          size: 14,
                          color: isAvailable ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: isAvailable ? (val) => _onToggleEndpoint(ep, val) : null,
                    disabledColor: Colors.grey.withValues(alpha: 0.3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          childAspectRatio = 1.8; // Увеличиваем в 1.5 раза (1.2 * 1.5 = 1.8)
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.95; // Увеличиваем в 1.5 раза (1.3 * 1.5 = 1.95)
        } else {
          crossAxisCount = 2;
          childAspectRatio = 1.8; // Увеличиваем в 1.5 раза (1.2 * 1.5 = 1.8)
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
                  value: _metrics!.networkRxRate != null ? _convertToMbps(_metrics!.networkRxRate!) : 0,
                  unit: 'Mbps',
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
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
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
    if (_metrics == null) {
      return const SizedBox.shrink();
    }
    
    // Показываем детальную информацию даже если isOnline = false, если есть данные
    if (!_metrics!.isOnline && !_hasAdditionalData()) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                if (isNarrow) {
                  // Для узких экранов - вертикальный layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Детальная информация',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_hasAdditionalData()) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _showAdditionalDataInfo,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Дополнительные данные',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                } else {
                  // Для широких экранов - горизонтальный layout
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Детальная информация',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasAdditionalData()) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _showAdditionalDataInfo,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Дополнительные данные',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }
              },
            ),
            if (_hasAdditionalData()) ...[
              const SizedBox(height: 4),
              Text(
                'Расширенная информация о системе: процессы, версии, сенсоры и другие детали',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildMetricTabs(),
        const SizedBox(height: 16),
        _buildTabContent(),
      ],
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 350, // Уменьшенная высота для лучшего отображения
      child: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KeyedSubtree(
              key: ValueKey('system_${_contentUpdateCounter}_${_tabController.index}'),
              child: _buildSystemTab(),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KeyedSubtree(
              key: ValueKey('network_${_contentUpdateCounter}_${_tabController.index}'),
              child: _buildNetworkTab(),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KeyedSubtree(
              key: ValueKey('storage_${_contentUpdateCounter}_${_tabController.index}'),
              child: _buildStorageTab(),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: KeyedSubtree(
              key: ValueKey('performance_${_contentUpdateCounter}_${_tabController.index}'),
              child: _buildPerformanceTab(),
            ),
          ),
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
    
    // Ограничиваем количество отображаемых деталей для предотвращения переполнения
    final maxDetails = 8;
    final displayDetails = details.take(maxDetails).toList();
    final hasMore = details.length > maxDetails;

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
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...displayDetails.map((detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            if (hasMore) ...[
              const SizedBox(height: 4),
              Text(
                '... и ещё ${details.length - maxDetails} элементов',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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

  bool _hasAdditionalData() {
    if (_metrics == null) return false;
    
    return _metrics!.uptimeText != null ||
           _metrics!.systemInfo != null ||
           _metrics!.versionInfo != null ||
           _metrics!.processCount != null ||
           _metrics!.sensors != null ||
           _metrics!.smart != null ||
           _metrics!.docker != null ||
           _metrics!.wifi != null ||
           _metrics!.load != null ||
           _metrics!.alert != null ||
           _metrics!.gpu != null ||
           _metrics!.diskio != null ||
           _metrics!.folders != null ||
           _metrics!.connections != null ||
           _metrics!.containers != null ||
           _metrics!.ports != null ||
           _metrics!.vms != null ||
           _metrics!.amps != null ||
           _metrics!.cloud != null ||
           _metrics!.ip != null ||
           _metrics!.irq != null ||
           _metrics!.programlist != null ||
           _metrics!.psutilversion != null ||
           _metrics!.help != null ||
           _metrics!.core != null;
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
      // API v4 - всегда показываем кумулятивные данные (более точные)
      networkDetails.addAll([
        '📊 Кумулятивный RX: ${_formatBytes(_metrics!.networkRx)}',
        '📊 Кумулятивный TX: ${_formatBytes(_metrics!.networkTx)}',
      ]);
      
      // Проверяем, отличаются ли gauge данные от cumulative
      final gaugeRx = _metrics!.networkRxGauge ?? 0;
      final gaugeTx = _metrics!.networkTxGauge ?? 0;
      final cumulativeRx = _metrics!.networkRx;
      final cumulativeTx = _metrics!.networkTx;
      
      if (hasGaugeData && (gaugeRx != cumulativeRx || gaugeTx != cumulativeTx)) {
        // Показываем gauge данные только если они отличаются от cumulative
        networkDetails.addAll([
          '📈 Gauge RX: ${_formatBytes(gaugeRx)}',
          '📈 Gauge TX: ${_formatBytes(gaugeTx)}',
        ]);
        networkDetails.add('ℹ️ API v4: cumulative ≠ gauge');
      } else {
        networkDetails.add('ℹ️ API v4: cumulative = gauge');
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
      networkDetails.add('🚀 FastAPI: расширенные данные');
    } else if (isApiV3) {
      networkDetails.add('📡 API v3: стандартные данные');
    } else if (isApiV4) {
      networkDetails.add('🔧 API v4: точные кумулятивные данные');
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

  double _convertToMbps(double kbps) {
    // KB/s -> Kbps (умножаем на 8 для перевода байт в биты)
    // Kbps -> Mbps (делим на 1000 для перевода килобит в мегабиты)
    return (kbps * 8) / 1000;
  }

  String _getValidDropdownValue() {
    // Проверяем, что выбранный интерфейс существует в списке
    if (_selectedNetworkInterface == 'auto') {
      return 'auto';
    }
    
    // Убираем дубликаты из списка для проверки
    final uniqueInterfaces = _availableNetworkInterfaces.toSet();
    if (uniqueInterfaces.contains(_selectedNetworkInterface)) {
      return _selectedNetworkInterface;
    }
    
    // Если выбранный интерфейс не найден, возвращаем 'auto'
    return 'auto';
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'auto',
        child: Text('Автоматически'),
      ),
    ];

    // Убираем дубликаты и пустые строки, сортируем для консистентности
    final uniqueInterfaces = _availableNetworkInterfaces
        .where((interface) => interface.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    for (final interface in uniqueInterfaces) {
      items.add(
        DropdownMenuItem(
          value: interface,
          child: Text(interface),
        ),
      );
    }

    return items;
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

  void _showAdditionalDataInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дополнительные данные'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Дополнительные данные включают расширенную информацию о системе:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('📊 Процессы и их количество'),
              Text('🔧 Версии системы и компонентов'),
              Text('🌡️ Сенсоры (температура, вентиляторы)'),
              Text('🐳 Docker контейнеры'),
              Text('🌐 Сетевые соединения'),
              Text('💾 Дисковые операции'),
              Text('📁 Папки и их размеры'),
              Text('🔌 Порты и подключения'),
              SizedBox(height: 12),
              Text(
                'Как получить эти данные:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('1. Убедитесь что Glances запущен с расширенными опциями'),
              Text('2. Используйте команду: glances -w --port 61208 --enable-plugin sensors,smart,docker'),
              Text('3. Или настройте дополнительные endpoints в настройках сервера'),
              SizedBox(height: 12),
              Text(
                'Эти данные помогают получить полную картину состояния сервера!',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
