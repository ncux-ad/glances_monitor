import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String icon;
  final double value;
  final String unit;
  final String? subtitle;
  final Color? color;

  const MetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.unit,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = _getProgressColor(value);
    final cardColor = color ?? theme.colorScheme.surface;

    return Card(
      elevation: 2,
      color: cardColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Адаптивные размеры в зависимости от доступного пространства
          final isCompact = constraints.maxHeight < 120 || constraints.maxWidth < 180;
          final padding = isCompact ? 6.0 : 8.0;
          
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Заголовок с иконкой
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      icon,
                      style: TextStyle(fontSize: isCompact ? 16.0 : 24.0),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        style: isCompact 
                            ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
                            : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Значение
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: isCompact
                      ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: progressColor)
                      : theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: progressColor),
                  textAlign: TextAlign.center,
                ),
                // Прогресс-бар
                LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: isCompact ? 4 : 6,
                ),
                // Подпись (только если есть достаточно места)
                if (subtitle != null && !isCompact && constraints.maxHeight > 140) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getProgressColor(double value) {
    if (value < 60) {
      return Colors.green;
    } else if (value < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class MetricCardWithDetails extends StatelessWidget {
  final String title;
  final String icon;
  final double value;
  final String unit;
  final List<String> details;

  const MetricCardWithDetails({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.unit,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = _getProgressColor(value);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: value / 100,
              backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double value) {
    if (value < 60) {
      return Colors.green;
    } else if (value < 80) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

