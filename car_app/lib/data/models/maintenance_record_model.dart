import '../../domain/entities/maintenance_record.dart' as entity;
class MaintenanceRecordModel {
  final String id;
  final String type;
  final int lastChangeKM;
  final int recommendedIntervalKM;
  final int nextChangeKM;
  final DateTime lastChangeDate;
  final String? notes;

  MaintenanceRecordModel({
    required this.id,
    required this.type,
    required this.lastChangeKM,
    required this.recommendedIntervalKM,
    required this.nextChangeKM,
    required this.lastChangeDate,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'last_change_km': lastChangeKM,
    'recommended_interval_km': recommendedIntervalKM,
    'next_change_km': nextChangeKM,
    'last_change_date': lastChangeDate.toIso8601String(),
    'notes': notes,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory MaintenanceRecordModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecordModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      lastChangeKM: json['last_change_km'] ?? 0,
      recommendedIntervalKM: json['recommended_interval_km'] ?? 0,
      nextChangeKM: json['next_change_km'] ?? 0,
      lastChangeDate: json['last_change_date'] != null 
          ? DateTime.parse(json['last_change_date'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }

  entity.MaintenanceRecord toEntity() {
    return entity.MaintenanceRecord(
      id: id,
      type: type,
      lastChangeKM: lastChangeKM,
      recommendedIntervalKM: recommendedIntervalKM,
      nextChangeKM: nextChangeKM,
      lastChangeDate: lastChangeDate,
      notes: notes,
    );
  }
} 