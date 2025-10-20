import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../models/system_metrics.dart';

class ServerListTile extends StatelessWidget {
  final ServerConfig server;
  final SystemMetrics? metrics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ServerListTile({
    super.key,
    required this.server,
    this.metrics,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = metrics?.isOnline ?? false;
    final statusColor = isOnline ? Colors.green : Colors.red;
    final statusText = isOnline ? 'Онлайн' : 'Офлайн';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Text(
            server.flag,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          server.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              server.url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Отображение версии API
                if (metrics?.apiVersion != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getApiVersionColor(metrics!.apiVersion!).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getApiVersionColor(metrics!.apiVersion!).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'API v${metrics!.apiVersion}',
                      style: TextStyle(
                        color: _getApiVersionColor(metrics!.apiVersion!),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (isOnline && metrics != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildMetricChip('CPU', metrics!.cpuPercent, theme),
                        _buildMetricChip('RAM', metrics!.memPercent, theme),
                        _buildMetricChip('Disk', metrics!.diskPercent, theme),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isOnline
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : const Icon(Icons.error_outline, color: Colors.red, size: 20),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildMetricChip(String label, double value, ThemeData theme) {
    Color color;
    if (value < 60) {
      color = Colors.green;
    } else if (value < 80) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
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
}

