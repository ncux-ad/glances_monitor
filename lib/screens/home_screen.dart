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
        final metrics = await _apiService.getServerMetrics(server);
        if (mounted) {
          setState(() {
            _serverMetrics[server.id] = metrics;
          });
        }
      } catch (e) {
        print('Ошибка загрузки метрик для ${server.name}: $e');
        if (mounted) {
          setState(() {
            _serverMetrics[server.id] = SystemMetrics.offline();
          });
        }
      }
    });

    await Future.wait(futures);
  }

  Future<void> _onRefresh() async {
    await _refreshAllMetrics();
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
            tooltip: 'О программе',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _onRefresh,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addServer,
        child: const Icon(Icons.add),
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
}

