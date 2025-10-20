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
          final padding = isCompact ? 4.0 : 6.0;
          
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Заголовок с иконкой
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: isCompact ? 18 : 24, // Уменьшаем высоту блока в 1.5 раза
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.center,
                          heightFactor: 0.67, // Обрезаем высоту в 1.5 раза
                          child: Text(
                            icon,
                            style: TextStyle(
                              fontSize: isCompact ? 16.0 : 20.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        title,
                        style: isCompact 
                            ? theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              )
                            : theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                              ),
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
                      ? theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: progressColor,
                          fontSize: 20,
                        )
                      : theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: progressColor,
                          fontSize: 22,
                        ),
                  textAlign: TextAlign.center,
                ),
                // Прогресс-бар
                LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: isCompact ? 4 : 5,
                ),
                // Подпись (всегда показываем, но компактно)
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: isCompact ? 14 : 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
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
                SizedBox(
                  height: 24, // Уменьшаем высоту блока в 1.5 раза (было ~36)
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      heightFactor: 0.67, // Обрезаем высоту в 1.5 раза
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: value / 100,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
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
