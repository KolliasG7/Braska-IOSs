// lib/models/gpu.dart

class GpuLevel {
  final int index;
  final String label;
  final int? mhz;
  final bool hasMhz;
  final bool active;

  const GpuLevel({
    required this.index,
    required this.label,
    this.mhz,
    required this.hasMhz,
    required this.active,
  });

  factory GpuLevel.fromJson(Map<String, dynamic> j) => GpuLevel(
    index: j['index'] as int? ?? 0,
    label: j['label'] as String? ?? '',
    mhz: j['mhz'] as int?,
    hasMhz: j['has_mhz'] as bool? ?? false,
    active: j['active'] as bool? ?? false,
  );

  String get displayLabel => hasMhz && mhz != null ? '$mhz MHz' : label;
}

class GpuState {
  final bool available;
  final bool supportedHardware;
  final String? variant;
  final String? vendorId;
  final String? deviceId;
  final String? message;
  final String? warning;
  final String? performanceLevel;
  final List<GpuLevel> levels;
  final bool hasActiveLevel;
  final int? activeLevel;

  const GpuState({
    required this.available,
    required this.supportedHardware,
    this.variant,
    this.vendorId,
    this.deviceId,
    this.message,
    this.warning,
    this.performanceLevel,
    this.levels = const [],
    required this.hasActiveLevel,
    this.activeLevel,
  });

  factory GpuState.fromJson(Map<String, dynamic> j) {
    final levelsList = j['levels'] as List?;
    return GpuState(
      available: j['available'] as bool? ?? false,
      supportedHardware: j['supported_hardware'] as bool? ?? false,
      variant: j['variant'] as String?,
      vendorId: j['vendor_id'] as String?,
      deviceId: j['device_id'] as String?,
      message: j['message'] as String?,
      warning: j['warning'] as String?,
      performanceLevel: j['performance_level'] as String?,
      levels: levelsList != null
          ? levelsList
              .whereType<Map>()
              .map((e) => GpuLevel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      hasActiveLevel: j['has_active_level'] as bool? ?? false,
      activeLevel: j['active_level'] as int?,
    );
  }

  bool get isManual => performanceLevel?.toLowerCase() == 'manual';
  GpuLevel? get activeLevelObj => levels.cast<GpuLevel?>().firstWhere(
        (l) => l?.active == true,
        orElse: () => null,
      );
}
