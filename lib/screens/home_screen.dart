import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';
import '../services/storage_service.dart';
import '../services/glances_api_service.dart';
import '../widgets/server_list_tile.dart';
import 'add_server_screen.dart';
import 'server_detail_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = GlancesApiService();
  List<ServerConfig> _servers = [];
  Map<String, SystemMetrics> _serverMetrics = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final servers = await StorageService.loadServers();
      setState(() {
        _servers = servers;
      });
      
      // Загружаем метрики для всех серверов
      await _refreshAllMetrics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки серверов: $e'),
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

  Future<void> _refreshAllMetrics() async {
    if (_servers.isEmpty) return;

    final futures = _servers.map((server) async {
      try {
        // Сначала быстрая проверка доступности сервера (healthcheck)
        final isServerOnline = await _apiService.testConnection(server);
        
        if (isServerOnline) {
          // Если сервер доступен, загружаем полные метрики
          final metrics = await _apiService.getServerMetrics(server);
          if (mounted) {
            setState(() {
              _serverMetrics[server.id] = metrics;
            });
          }
        } else {
          // Сервер недоступен - создаем offline метрики
          if (mounted) {
            setState(() {
              _serverMetrics[server.id] = SystemMetrics.offline(errorMessage: 'Сервер недоступен');
            });
          }
        }
      } catch (e) {
        print('Ошибка загрузки метрик для ${server.name}: $e');
        if (mounted) {
          setState(() {
            _serverMetrics[server.id] = SystemMetrics.offline(errorMessage: e.toString());
          });
        }
      }
    });

    await Future.wait(futures);
  }

  Future<void> _onRefresh() async {
    await _refreshAllMetrics();
  }

  /// Быстрая проверка статуса серверов без загрузки полных метрик
  Future<void> _quickHealthCheck() async {
    if (_servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет серверов для проверки'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Показываем индикатор загрузки
    setState(() {
      _isLoading = true;
    });

    // Убираем счетчики, так как больше не показываем уведомления

    final futures = _servers.map((server) async {
      try {
        final isOnline = await _apiService.testConnection(server);
        if (mounted) {
          setState(() {
            // Обновляем только статус онлайн/офлайн, не загружая полные метрики
            if (isOnline) {
              // Если сервер онлайн, но метрик нет - создаем минимальные онлайн метрики
              if (_serverMetrics[server.id] == null || !_serverMetrics[server.id]!.isOnline) {
                _serverMetrics[server.id] = SystemMetrics(
                  cpuPercent: 0.0,
                  memPercent: 0.0,
                  diskPercent: 0.0,
                  swapPercent: 0.0,
                  memTotal: 0,
                  memUsed: 0,
                  memFree: 0,
                  swapTotal: 0,
                  swapUsed: 0,
                  swapFree: 0,
                  diskTotal: 0,
                  diskUsed: 0,
                  diskFree: 0,
                  cpuName: 'Проверка...',
                  cpuHz: 0.0,
                  cpuCores: 0,
                  networkInterface: 'Проверка...',
                  networkRx: 0,
                  networkTx: 0,
                  isOnline: true,
                  apiVersion: null, // Будет определен при полной загрузке
                );
              }
            } else {
              _serverMetrics[server.id] = SystemMetrics.offline(errorMessage: 'Сервер недоступен');
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _serverMetrics[server.id] = SystemMetrics.offline(errorMessage: e.toString());
          });
        }
      }
    });

    await Future.wait(futures);

    // Скрываем индикатор загрузки
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Обновляем данные без показа уведомлений
    }
  }

  /// Обработка действий из меню
  void _handleMenuAction(String action) {
    switch (action) {
      case 'health_check':
        _quickHealthCheck();
        break;
      case 'export_settings':
        _exportSettings();
        break;
      case 'import_settings':
        _importSettings();
        break;
      case 'about':
        _showAbout();
        break;
    }
  }

  void _addServer() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddServerScreen(),
      ),
    );

    if (result == true) {
      _loadServers();
    }
  }

  void _editServer(ServerConfig server) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddServerScreen(server: server),
      ),
    );

    if (result == true) {
      _loadServers();
    }
  }

  void _deleteServer(ServerConfig server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сервер'),
        content: Text('Вы уверены, что хотите удалить сервер "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await StorageService.deleteServer(server.id);
      if (mounted) {
        if (success) {
          _loadServers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сервер удален'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка удаления сервера'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToServerDetail(ServerConfig server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ServerDetailScreen(server: server),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glances Monitor'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          // Главная кнопка - обновление с умным функционалом
          GestureDetector(
            onTap: _onRefresh,
            onLongPress: _quickHealthCheck,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: null, // Обрабатывается в GestureDetector
              tooltip: 'Обновить (долгое нажатие - проверка статуса)',
            ),
          ),
          // Меню с дополнительными действиями
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'health_check',
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Проверка статуса'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_settings',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Экспорт настроек'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import_settings',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20),
                    SizedBox(width: 8),
                    Text('Импорт настроек'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 8),
                    Text('О программе'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addServer,
        icon: const Icon(Icons.add),
        label: const Text('Добавить сервер'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _servers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_servers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _servers.length,
        itemBuilder: (context, index) {
          final server = _servers[index];
          final metrics = _serverMetrics[server.id];

          return ServerListTile(
            server: server,
            metrics: metrics,
            onTap: () => _navigateToServerDetail(server),
            onLongPress: () => _showServerOptions(server),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет серверов',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте сервер для мониторинга',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addServer,
              icon: const Icon(Icons.add),
              label: const Text('Добавить сервер'),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerOptions(ServerConfig server) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.of(context).pop();
                _editServer(server);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteServer(server);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
      ),
    );
  }

  void _exportSettings() async {
    try {
      final success = await StorageService.copyToClipboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Настройки скопированы в буфер обмена' 
              : 'Ошибка экспорта настроек'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _importSettings() async {
    // Простое решение - показать диалог с инструкциями
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт настроек'),
          content: const Text(
            'Для импорта настроек:\n\n'
            '1. Скопируйте JSON с настройками в буфер обмена\n'
            '2. Нажмите "Вставить" в следующем диалоге\n\n'
            'Настройки будут заменены на импортированные.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showImportDialog();
              },
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
    }
  }

  void _showImportDialog() async {
    final controller = TextEditingController();
    
    if (mounted) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт настроек'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Вставьте JSON с настройками серверов',
              border: OutlineInputBorder(),
            ),
            maxLines: 10,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Импорт'),
            ),
          ],
        ),
      );

      if (result != null && result.isNotEmpty) {
        final success = await StorageService.importServers(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                ? 'Настройки успешно импортированы' 
                : 'Ошибка импорта настроек'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          
          if (success) {
            _loadServers(); // Перезагружаем список серверов
          }
        }
      }
    }
  }
}

