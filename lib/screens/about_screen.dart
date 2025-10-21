import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/build_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('О программе'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок приложения
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.monitor_heart,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Glances Monitor',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, String>>(
                    future: BuildInfo.getFullBuildInfo(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final info = snapshot.data!;
                        return Column(
                          children: [
                            Text(
                              'Версия ${info['version']}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Сборка ${info['buildNumber']}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commit: ${info['commitHash']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline.withValues(alpha: 0.6),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Дата: ${info['buildDate']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Text(
                          'Версия 1.0.0',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Описание
            _buildSection(
              title: 'Описание',
              content: 'Мобильное приложение для мониторинга серверов через Glances REST API. Позволяет отслеживать системные метрики, сетевую активность, процессы и многое другое в режиме реального времени.',
              icon: Icons.info_outline,
            ),
            
            const SizedBox(height: 24),
            
            // Основные функции
            _buildSection(
              title: 'Основные функции',
              content: '',
              icon: Icons.star_outline,
              children: [
                _buildFeatureItem('🖥️ Мониторинг серверов', 'Отслеживание CPU, памяти, диска, сети'),
                _buildFeatureItem('🌐 Сетевая диагностика', 'Анализ сетевых интерфейсов и трафика'),
                _buildFeatureItem('🔧 Диагностика endpoint', 'Проверка доступности Glances API'),
                _buildFeatureItem('📊 Настраиваемые метрики', 'Выбор нужных параметров мониторинга'),
                _buildFeatureItem('🔒 Безопасность', 'Поддержка Basic Auth и различных способов подключения'),
                _buildFeatureItem('📱 Удобный интерфейс', 'Современный Material Design'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Технические детали
            _buildSection(
              title: 'Технические детали',
              content: '',
              icon: Icons.settings_outlined,
              children: [
                _buildTechItem('Flutter SDK', '>=3.0.0'),
                _buildTechItem('Glances API', 'v3/v4'),
                _buildTechItem('Протокол', 'HTTP/HTTPS'),
                _buildTechItem('Аутентификация', 'Basic Auth'),
                _buildTechItem('Платформы', 'Android, iOS'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Разработчик
            _buildSection(
              title: 'Разработчик',
              content: 'Приложение разработано для удобного мониторинга серверов через Glances API с расширенными возможностями диагностики и настройки.',
              icon: Icons.person_outline,
            ),
            
            const SizedBox(height: 24),
            
            // Исходный код
            _buildSection(
              title: 'Исходный код',
              content: 'Проект с открытым исходным кодом доступен на GitHub.',
              icon: Icons.code,
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('GitHub Repository'),
                  subtitle: const Text('https://github.com/ncux-ad/glances_monitor'),
                  onTap: () => _openGitHub(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Кнопки действий
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLicenseDialog(context),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Лицензия'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyVersionInfo(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Копировать'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Информация о сборке
            Center(
              child: Text(
                'Сборка: ${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    List<Widget>? children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ],
            if (children != null) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Лицензия'),
        content: const SingleChildScrollView(
          child: Text(
            'Glances Monitor v0.0.1\n\n'
            'Это приложение предоставляется "как есть" без каких-либо гарантий.\n\n'
            'Использование данного программного обеспечения означает согласие с условиями использования.\n\n'
            'Разработчик не несет ответственности за любые убытки, возникшие в результате использования данного приложения.\n\n'
            '© 2025 Glances Monitor. Все права защищены.',
          ),
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

  void _copyVersionInfo(BuildContext context) {
    final versionInfo = '''
Glances Monitor v0.0.1
Сборка: ${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}
Платформа: ${Theme.of(context).platform.name}
Flutter SDK: >=3.0.0
Glances API: v3/v4
''';
    
    Clipboard.setData(ClipboardData(text: versionInfo));
    // Информация скопирована без уведомления
  }

  void _openGitHub(BuildContext context) {
    // В реальном приложении здесь можно использовать url_launcher
    // для открытия ссылки в браузере
    // GitHub: https://github.com/ncux-ad/glances_monitor
  }
}
