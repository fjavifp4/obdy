import '../../domain/entities/maintenance_record.dart' as entity;
import '../../config/core/utils/text_normalizer.dart';

class MaintenanceRecordModel {
  final String id;
  final String type;
  final int lastChangeKM;
  final int recommendedIntervalKM;
  final int nextChangeKM;
  final DateTime lastChangeDate;
  final String? notes;
  final double kmSinceLastChange;

  MaintenanceRecordModel({
    required this.id,
    required this.type,
    required this.lastChangeKM,
    required this.recommendedIntervalKM,
    required this.nextChangeKM,
    required this.lastChangeDate,
    this.notes,
    this.kmSinceLastChange = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'last_change_km': lastChangeKM,
    'recommended_interval_km': recommendedIntervalKM,
    'next_change_km': nextChangeKM,
    'last_change_date': lastChangeDate.toIso8601String(),
    'notes': notes,
    'km_since_last_change': kmSinceLastChange,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory MaintenanceRecordModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecordModel(
      id: json['id'] ?? '',
      type: TextNormalizer.normalize(json['type'], defaultValue: '', cleanRedundant: true),
      lastChangeKM: json['last_change_km'] ?? 0,
      recommendedIntervalKM: json['recommended_interval_km'] ?? 0,
      nextChangeKM: json['next_change_km'] ?? 0,
      lastChangeDate: json['last_change_date'] != null 
          ? DateTime.parse(json['last_change_date'])
          : DateTime.now(),
      notes: TextNormalizer.normalize(json['notes'], defaultValue: ''),
      kmSinceLastChange: (json['km_since_last_change'] ?? 0.0).toDouble(),
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
      kmSinceLastChange: kmSinceLastChange,
    );
  }
} 