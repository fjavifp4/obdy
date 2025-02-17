class MaintenanceRecord {
  final String id;
  final String type;
  final int lastChangeKM;
  final int recommendedIntervalKM;
  final int nextChangeKM;
  final DateTime lastChangeDate;
  final String? notes;

  MaintenanceRecord({
    required this.id,
    required this.type,
    required this.lastChangeKM,
    required this.recommendedIntervalKM,
    required this.nextChangeKM,
    required this.lastChangeDate,
    this.notes,
  });
} 