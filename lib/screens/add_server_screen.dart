import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/server_config.dart';
import '../services/storage_service.dart';
import '../services/glances_api_service.dart';
import 'endpoint_diagnostics_screen.dart';
import 'connection_options_screen.dart';

class AddServerScreen extends StatefulWidget {
  final ServerConfig? server; // null для добавления, не null для редактирования

  const AddServerScreen({super.key, this.server});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _flagController = TextEditingController();
  final Map<String, bool> _metricSelections = {
    'cpu': true,
    'mem': true,
    'fs': true,
    'network': true,
    'swap': true,
  };
  // Endpoint API выбор и доступность
  final Map<String, bool> _endpointAvailable = {};
  Set<String> _selectedEndpoints = {
    'quicklook','mem','memswap','fs','cpu','network','uptime','system'
  };
  
  bool _useHttps = false;

  // Сетевые интерфейсы
  String _selectedNetworkInterface = 'auto';
  List<String> _availableNetworkInterfaces = [];

  final _apiService = GlancesApiService();
  bool _isLoading = false;
  bool _isTesting = false;

  final List<String> _predefinedFlags = ['🇩🇪', '🇷🇺', '🇺🇸', '🇬🇧', '🇫🇷', '🇯🇵', '🇨🇳', '🇮🇳'];

  @override
  void initState() {
    super.initState();
    if (widget.server != null) {
      _nameController.text = widget.server!.name;
      _hostController.text = widget.server!.host;
      _portController.text = widget.server!.port.toString();
      _usernameController.text = widget.server!.username;
      _passwordController.text = widget.server!.password;
      _flagController.text = widget.server!.flag;
      // Инициализируем выбранные метрики
      for (final key in _metricSelections.keys) {
        _metricSelections[key] = widget.server!.selectedMetrics.contains(key);
      }
      // Инициализируем выбранные endpoint
      _selectedEndpoints = widget.server!.selectedEndpoints.toSet();
      // Инициализируем выбранный сетевой интерфейс
      _selectedNetworkInterface = widget.server!.selectedNetworkInterfaces.isNotEmpty
          ? widget.server!.selectedNetworkInterfaces.first
          : 'auto';
      _useHttps = widget.server!.useHttps;
    } else {
      _portController.text = '61208'; // значение по умолчанию
      _flagController.text = '🇩🇪'; // значение по умолчанию
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _flagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.server != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Редактировать сервер' : 'Добавить сервер',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteServer,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Название сервера',
              hint: 'Например: Germany Server',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название сервера';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _hostController,
                    label: 'Хост сервера',
                    hint: 'example.com или 192.168.1.1',
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите хост сервера';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _portController,
                    label: 'Порт',
                    hint: '61208',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите порт';
                      }
                      final port = int.tryParse(value);
                      if (port == null || port < 1 || port > 65535) {
                        return 'Порт должен быть от 1 до 65535';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: 'Имя пользователя (необязательно)',
              hint: 'your-username',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Пароль (необязательно)',
              hint: 'Пароль для доступа к Glances',
              obscureText: true,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Использовать HTTPS'),
              subtitle: const Text('Включите, если сервер работает через TLS'),
              value: _useHttps,
              onChanged: (val) => setState(() => _useHttps = val),
            ),
            const SizedBox(height: 8),
            _buildFlagSelector(),
          const SizedBox(height: 16),
          _buildMetricsSelector(),
          const SizedBox(height: 16),
          _buildEndpointSelector(),
          const SizedBox(height: 16),
          _buildNetworkInterfaceSelector(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTesting ? 'Проверка...' : 'Тест подключения'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveServer,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(isEditing ? 'Сохранить' : 'Добавить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }

  Widget _buildFlagSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Флаг сервера',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _flagController,
          decoration: const InputDecoration(
            hintText: 'Введите эмодзи флага',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Выберите флаг';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _predefinedFlags.map((flag) {
            final isSelected = _flagController.text == flag;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _flagController.text = flag;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Выберите метрики',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _metricSelections.keys.map((key) {
            final label = {
              'cpu': 'CPU',
              'mem': 'Память',
              'fs': 'Диск',
              'network': 'Сеть',
              'swap': 'Swap',
            }[key]!
            ;
            return FilterChip(
              label: Text(label),
              selected: _metricSelections[key] == true,
              onSelected: (val) {
                setState(() {
                  _metricSelections[key] = val;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEndpointSelector() {
    final theme = Theme.of(context);
    final endpoints = GlancesApiService.knownEndpoints;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Endpoint API',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // Адаптивная раскладка кнопок
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    if (isNarrow) {
                      // В узком экране - вертикальная раскладка
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextButton.icon(
                            onPressed: _scanEndpoints,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Проверить endpoints'),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _openEndpointDiagnostics,
                            icon: const Icon(Icons.bug_report, size: 18),
                            label: const Text('Диагностика'),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _openConnectionOptions,
                            icon: const Icon(Icons.settings_ethernet, size: 18),
                            label: const Text('Варианты подключения'),
                          ),
                        ],
                      );
                    } else {
                      // В широком экране - горизонтальная раскладка
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _scanEndpoints,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Проверить'),
                          ),
                          TextButton.icon(
                            onPressed: _openEndpointDiagnostics,
                            icon: const Icon(Icons.bug_report, size: 18),
                            label: const Text('Диагностика'),
                          ),
                          TextButton.icon(
                            onPressed: _openConnectionOptions,
                            icon: const Icon(Icons.settings_ethernet, size: 18),
                            label: const Text('Подключение'),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: endpoints.map((ep) {
                final available = _endpointAvailable[ep];
                Color? chipColor;
                if (available == true) chipColor = Colors.green.withValues(alpha: 0.12);
                if (available == false) chipColor = Colors.red.withValues(alpha: 0.10);
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ep, style: TextStyle(fontSize: isNarrow ? 12 : 14)),
                      if (available == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle, color: Colors.green, size: isNarrow ? 14 : 16),
                      ] else if (available == false) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.error_outline, color: Colors.red, size: isNarrow ? 14 : 16),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => _showEndpointHelp(ep),
                          child: Icon(Icons.info_outline, color: theme.colorScheme.primary, size: isNarrow ? 14 : 16),
                        ),
                      ]
                    ],
                  ),
                  selected: _selectedEndpoints.contains(ep),
                  selectedColor: chipColor,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedEndpoints.add(ep);
                      } else {
                        _selectedEndpoints.remove(ep);
                      }
                    });
                  },
                );
              }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
    });

    try {
      final server = _createServerFromForm();
      await _apiService.testConnection(server);

      // Тестируем подключение без показа уведомлений
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final server = _createServerFromForm();
      final success = widget.server != null
          ? await StorageService.updateServer(server)
          : await StorageService.addServer(server);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка сохранения сервера'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
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

  Future<void> _deleteServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сервер'),
        content: const Text('Вы уверены, что хотите удалить этот сервер?'),
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

    if (confirmed == true && widget.server != null) {
      final success = await StorageService.deleteServer(widget.server!.id);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
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

  ServerConfig _createServerFromForm() {
    final id = widget.server?.id ?? const Uuid().v4();
    return ServerConfig(
      id: id,
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      flag: _flagController.text.trim(),
      selectedMetrics: _metricSelections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      selectedEndpoints: _selectedEndpoints.toList(),
      selectedNetworkInterfaces: _selectedNetworkInterface == 'auto'
          ? []
          : [_selectedNetworkInterface],
      useHttps: _useHttps,
    );
  }

  Future<void> _scanEndpoints() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
    });
    try {
      final tempServer = _createServerFromForm();
      final map = await _apiService.scanAvailableEndpoints(tempServer);
      if (mounted) {
        setState(() {
          _endpointAvailable
            ..clear()
            ..addAll(map);
          // Автовыбор: включать только доступные + разумный набор
          _selectedEndpoints = _selectedEndpoints.where((ep) => map[ep] != false).toSet();
          if (_selectedEndpoints.isEmpty) {
            _selectedEndpoints = map.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toSet();
            _selectedEndpoints.add('quicklook');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сканирования endpoint: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _showEndpointHelp(String ep) {
    final Map<String, String> tips = {
      'sensors': 'Установите lm-sensors: sudo apt install lm-sensors && sudo sensors-detect',
      'smart': 'Установите smartmontools: sudo apt install smartmontools',
      'raid': 'Установите mdadm: sudo apt install mdadm',
      'docker': 'Добавьте пользователя glances в группу docker и перезапустите docker',
      'wifi': 'Доступно только на системах с Wi‑Fi адаптером',
      'processlist': 'Ограничьте объем: запрашивайте top N процессов для производительности',
    };
    final text = tips[ep] ?? 'Плагин может быть недоступен на этой системе или отключен.';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Как включить "$ep"', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkInterfaceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Сетевой интерфейс',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _scanNetworkInterfaces,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _getValidNetworkInterfaceValue(),
              decoration: const InputDecoration(
                labelText: 'Выберите интерфейс',
                border: OutlineInputBorder(),
              ),
              items: _buildNetworkInterfaceItems(),
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
      ),
    );
  }

  Future<void> _scanNetworkInterfaces() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
    });
    try {
      final tempServer = _createServerFromForm();
      final interfaces = await _apiService.fetchNetworkInterfaces(tempServer);
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
          SnackBar(content: Text('Ошибка получения интерфейсов: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _openEndpointDiagnostics() {
    if (!_formKey.currentState!.validate()) return;
    
    final tempServer = _createServerFromForm();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EndpointDiagnosticsScreen(server: tempServer),
      ),
    );
  }

  void _openConnectionOptions() {
    if (!_formKey.currentState!.validate()) return;
    
    final tempServer = _createServerFromForm();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectionOptionsScreen(server: tempServer),
      ),
    );
  }

  String _getValidNetworkInterfaceValue() {
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

  List<DropdownMenuItem<String>> _buildNetworkInterfaceItems() {
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
}

