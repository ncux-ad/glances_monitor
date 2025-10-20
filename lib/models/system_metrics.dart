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
  final int? networkRxGauge; // Кумулятивный RX трафик (FastAPI)
  final int? networkTxGauge; // Кумулятивный TX трафик (FastAPI)
  final double? networkRxRate; // Скорость RX в байтах/сек (FastAPI)
  final double? networkTxRate; // Скорость TX в байтах/сек (FastAPI)
  final int? networkRxCurrent; // Текущая скорость RX (API v3)
  final int? networkTxCurrent; // Текущая скорость TX (API v3)
  final bool isOnline;
  final String? errorMessage;
  final int? apiVersion; // Версия API Glances (3, 4, или null если неизвестно)

  // Дополнительные (опциональные) данные из других endpoint
  final String? uptimeText; // из /uptime, строка наподобие "1 day, 02:03:04"
  final Map<String, dynamic>? systemInfo; // из /system
  final Map<String, dynamic>? versionInfo; // из /version
  final Map<String, dynamic>? processCount; // из /processcount
  final List<Map<String, dynamic>>? processList; // из /processlist
  final List<Map<String, dynamic>>? sensors; // из /sensors
  final List<Map<String, dynamic>>? smart; // из /smart
  final List<Map<String, dynamic>>? raid; // из /raid
  final List<Map<String, dynamic>>? docker; // из /docker
  final List<Map<String, dynamic>>? wifi; // из /wifi
  final Map<String, dynamic>? load; // из /load
  final Map<String, dynamic>? alert; // из /alert
  final List<Map<String, dynamic>>? gpu; // из /gpu
  final List<Map<String, dynamic>>? diskio; // из /diskio
  final List<Map<String, dynamic>>? folders; // из /folders
  final List<Map<String, dynamic>>? connections; // из /connections
  final List<Map<String, dynamic>>? containers; // из /containers
  final List<Map<String, dynamic>>? ports; // из /ports
  final List<Map<String, dynamic>>? vms; // из /vms
  final List<Map<String, dynamic>>? amps; // из /amps
  final List<Map<String, dynamic>>? cloud; // из /cloud
  final List<Map<String, dynamic>>? ip; // из /ip
  final List<Map<String, dynamic>>? irq; // из /irq
  final List<Map<String, dynamic>>? programlist; // из /programlist
  final Map<String, dynamic>? psutilversion; // из /psutilversion
  final Map<String, dynamic>? help; // из /help
  final Map<String, dynamic>? core; // из /core

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
    this.networkRxGauge,
    this.networkTxGauge,
    this.networkRxRate,
    this.networkTxRate,
    this.networkRxCurrent,
    this.networkTxCurrent,
    required this.isOnline,
    this.errorMessage,
    this.apiVersion,
    this.uptimeText,
    this.systemInfo,
    this.versionInfo,
    this.processCount,
    this.processList,
    this.sensors,
    this.smart,
    this.raid,
    this.docker,
    this.wifi,
    this.load,
    this.alert,
    this.gpu,
    this.diskio,
    this.folders,
    this.connections,
    this.containers,
    this.ports,
    this.vms,
    this.amps,
    this.cloud,
    this.ip,
    this.irq,
    this.programlist,
    this.psutilversion,
    this.help,
    this.core,
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
      networkRxGauge: null,
      networkTxGauge: null,
      networkRxRate: null,
      networkTxRate: null,
      networkRxCurrent: null,
      networkTxCurrent: null,
      isOnline: false,
      errorMessage: errorMessage,
      uptimeText: null,
      systemInfo: null,
      versionInfo: null,
      processCount: null,
      processList: null,
      sensors: null,
      smart: null,
      raid: null,
      docker: null,
      wifi: null,
      load: null,
      alert: null,
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
    String? uptimeText,
    Map<String, dynamic>? systemInfo,
    Map<String, dynamic>? versionInfo,
    Map<String, dynamic>? processCount,
    List<Map<String, dynamic>>? processList,
    List<Map<String, dynamic>>? sensors,
    List<Map<String, dynamic>>? smart,
    List<Map<String, dynamic>>? raid,
    List<Map<String, dynamic>>? docker,
    List<Map<String, dynamic>>? wifi,
    Map<String, dynamic>? load,
    Map<String, dynamic>? alert,
    List<Map<String, dynamic>>? gpu,
    List<Map<String, dynamic>>? diskio,
    List<Map<String, dynamic>>? folders,
    List<Map<String, dynamic>>? connections,
    List<Map<String, dynamic>>? containers,
    List<Map<String, dynamic>>? ports,
    List<Map<String, dynamic>>? vms,
    List<Map<String, dynamic>>? amps,
    List<Map<String, dynamic>>? cloud,
    List<Map<String, dynamic>>? ip,
    List<Map<String, dynamic>>? irq,
    List<Map<String, dynamic>>? programlist,
    Map<String, dynamic>? psutilversion,
    Map<String, dynamic>? help,
    Map<String, dynamic>? core,
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
    // Получаем gauge поля для FastAPI
    final networkRxGauge = (mainInterface['bytes_recv_gauge'] as num?)?.toInt();
    final networkTxGauge = (mainInterface['bytes_sent_gauge'] as num?)?.toInt();
    final networkRxRate = (mainInterface['bytes_recv_rate_per_sec'] as num?)?.toDouble();
    final networkTxRate = (mainInterface['bytes_sent_rate_per_sec'] as num?)?.toDouble();
    
    // Определяем основные поля для общего трафика
    // Приоритизируем cumulative поля для получения точных данных о реальном объеме трафика
    int networkRx, networkTx;
    final cumulativeRx = (mainInterface['cumulative_rx'] as num?)?.toInt() ?? 0;
    final cumulativeTx = (mainInterface['cumulative_tx'] as num?)?.toInt() ?? 0;
    
    if (cumulativeRx > 0 || cumulativeTx > 0) {
      // Используем cumulative поля как основные (более точные данные)
      networkRx = cumulativeRx;
      networkTx = cumulativeTx;
    } else if (networkRxGauge != null && networkTxGauge != null) {
      // Fallback на gauge поля если cumulative недоступны
      networkRx = networkRxGauge;
      networkTx = networkTxGauge;
    } else {
      // Последний fallback
      networkRx = 0;
      networkTx = 0;
    }
    
    // Если cumulative и gauge поля одинаковы, это означает что FastAPI возвращает корректные данные
    
    // Дополнительно получаем текущую скорость для API v3
    final networkRxCurrent = apiVersion == 3 ? (mainInterface['rx'] as num?)?.toInt() ?? 0 : null;
    final networkTxCurrent = apiVersion == 3 ? (mainInterface['tx'] as num?)?.toInt() ?? 0 : null;

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
      networkRxGauge: networkRxGauge,
      networkTxGauge: networkTxGauge,
      networkRxRate: networkRxRate,
      networkTxRate: networkTxRate,
      networkRxCurrent: networkRxCurrent,
      networkTxCurrent: networkTxCurrent,
      isOnline: true,
      apiVersion: apiVersion,
      uptimeText: uptimeText,
      systemInfo: systemInfo,
      versionInfo: versionInfo,
      processCount: processCount,
      processList: processList,
      sensors: sensors,
      smart: smart,
      raid: raid,
      docker: docker,
      wifi: wifi,
      load: load,
      alert: alert,
      gpu: gpu,
      diskio: diskio,
      folders: folders,
      connections: connections,
      containers: containers,
      ports: ports,
      vms: vms,
      amps: amps,
      cloud: cloud,
      ip: ip,
      irq: irq,
      programlist: programlist,
      psutilversion: psutilversion,
      help: help,
      core: core,
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
