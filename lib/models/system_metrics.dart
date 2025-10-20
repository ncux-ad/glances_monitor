import 'dart:math' as math;

class SystemMetrics {
  final double cpuPercent;
  final double memPercent;
  final double diskPercent;
  final double swapPercent;
  final int memTotal;
  final int memUsed;
  final int memFree;
  final int swapTotal;
  final int swapUsed;
  final int swapFree;
  final int diskTotal;
  final int diskUsed;
  final int diskFree;
  final String cpuName;
  final double cpuHz;
  final int cpuCores;
  final String networkInterface;
  final int networkRx;
  final int networkTx;
  final bool isOnline;
  final String? errorMessage;

  const SystemMetrics({
    required this.cpuPercent,
    required this.memPercent,
    required this.diskPercent,
    required this.swapPercent,
    required this.memTotal,
    required this.memUsed,
    required this.memFree,
    required this.swapTotal,
    required this.swapUsed,
    required this.swapFree,
    required this.diskTotal,
    required this.diskUsed,
    required this.diskFree,
    required this.cpuName,
    required this.cpuHz,
    required this.cpuCores,
    required this.networkInterface,
    required this.networkRx,
    required this.networkTx,
    required this.isOnline,
    this.errorMessage,
  });

  factory SystemMetrics.offline({String? errorMessage}) {
    return SystemMetrics(
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
      cpuName: 'Неизвестно',
      cpuHz: 0.0,
      cpuCores: 0,
      networkInterface: 'Неизвестно',
      networkRx: 0,
      networkTx: 0,
      isOnline: false,
      errorMessage: errorMessage,
    );
  }

  factory SystemMetrics.fromGlancesData({
    required Map<String, dynamic> quicklook,
    required Map<String, dynamic> memory,
    required Map<String, dynamic> memswap,
    required List<dynamic> disk,
    required Map<String, dynamic> cpu,
    required List<dynamic> network,
    required int apiVersion,
  }) {
    // CPU данные
    final cpuPercent = (quicklook['cpu'] as num?)?.toDouble() ?? 0.0;
    final cpuName = quicklook['cpu_name'] as String? ?? 'Неизвестно';
    final cpuHz = (quicklook['cpu_hz_current'] as num?)?.toDouble() ?? 0.0;
    final cpuCores = (quicklook['percpu'] as List?)?.length ?? 0;

    // Memory данные
    final memPercent = (memory['percent'] as num?)?.toDouble() ?? 0.0;
    final memTotal = (memory['total'] as num?)?.toInt() ?? 0;
    final memUsed = (memory['used'] as num?)?.toInt() ?? 0;
    final memFree = (memory['free'] as num?)?.toInt() ?? 0;

    // Swap данные
    final swapPercent = (memswap['percent'] as num?)?.toDouble() ?? 0.0;
    final swapTotal = (memswap['total'] as num?)?.toInt() ?? 0;
    final swapUsed = (memswap['used'] as num?)?.toInt() ?? 0;
    final swapFree = (memswap['free'] as num?)?.toInt() ?? 0;

    // Disk данные
    final diskList = disk as List?;
    final rootDisk = diskList?.isNotEmpty == true ? diskList!.first : null;
    final diskPercent = (rootDisk?['percent'] as num?)?.toDouble() ?? 0.0;
    final diskTotal = (rootDisk?['size'] as num?)?.toInt() ?? 0;
    final diskUsed = (rootDisk?['used'] as num?)?.toInt() ?? 0;
    final diskFree = (rootDisk?['free'] as num?)?.toInt() ?? 0;

    // Network данные
    final mainInterface = network.firstWhere(
      (iface) => iface['interface_name'] != 'lo' && 
                 iface['interface_name'] != 'docker0' && 
                 iface['is_up'] == true,
      orElse: () => network.isNotEmpty ? network.first : {},
    );
    final networkInterface = mainInterface['interface_name'] as String? ?? 'Неизвестно';
    final rxField = apiVersion == 3 ? 'rx' : 'cumulative_rx';
    final txField = apiVersion == 3 ? 'tx' : 'cumulative_tx';
    final networkRx = (mainInterface[rxField] as num?)?.toInt() ?? 0;
    final networkTx = (mainInterface[txField] as num?)?.toInt() ?? 0;

    return SystemMetrics(
      cpuPercent: cpuPercent,
      memPercent: memPercent,
      diskPercent: diskPercent,
      swapPercent: swapPercent,
      memTotal: memTotal,
      memUsed: memUsed,
      memFree: memFree,
      swapTotal: swapTotal,
      swapUsed: swapUsed,
      swapFree: swapFree,
      diskTotal: diskTotal,
      diskUsed: diskUsed,
      diskFree: diskFree,
      cpuName: cpuName,
      cpuHz: cpuHz,
      cpuCores: cpuCores,
      networkInterface: networkInterface,
      networkRx: networkRx,
      networkTx: networkTx,
      isOnline: true,
    );
  }

  String formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const k = 1024;
    final i = (math.log(bytes) / math.log(k)).floor();
    final clampedIndex = math.min(i, sizes.length - 1);
    return '${(bytes / math.pow(k, clampedIndex)).toStringAsFixed(1)} ${sizes[clampedIndex]}';
  }

  @override
  String toString() {
    return 'SystemMetrics(cpu: ${cpuPercent}%, mem: ${memPercent}%, disk: ${diskPercent}%, swap: ${swapPercent}%, online: $isOnline)';
  }
}
