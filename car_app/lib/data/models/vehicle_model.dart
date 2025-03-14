import '../../domain/entities/vehicle.dart' as entity;
import 'maintenance_record_model.dart';
import '../../config/core/utils/text_normalizer.dart';

class VehicleModel {
  final String id;
  final String userId;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;
  final List<MaintenanceRecordModel> maintenanceRecords;
  final String? pdfManualGridFsId;
  final String? logo;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.maintenanceRecords,
    this.pdfManualGridFsId,
    this.logo,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convertir a entidad
  entity.Vehicle toEntity() {
    return entity.Vehicle(
      id: id,
      userId: userId,
      brand: brand,
      model: model,
      year: year,
      licensePlate: licensePlate,
      currentKilometers: null, // Este campo no existe en el modelo
      maintenanceRecords: maintenanceRecords.map((record) => record.toEntity()).toList(),
      pdfManualGridFsId: pdfManualGridFsId,
      logo: logo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  VehicleModel copyWith({
    String? id,
    String? userId,
    String? brand,
    String? model,
    int? year,
    String? licensePlate,
    List<MaintenanceRecordModel>? maintenanceRecords,
    String? pdfManualGridFsId,
    String? logo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      maintenanceRecords: maintenanceRecords ?? this.maintenanceRecords,
      pdfManualGridFsId: pdfManualGridFsId ?? this.pdfManualGridFsId,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      userId: json['userId'],
      // Normalizar los nombres de marca y modelo
      brand: TextNormalizer.normalize(json['brand'], defaultValue: ''),
      model: TextNormalizer.normalize(json['model'], defaultValue: ''),
      year: json['year'],
      licensePlate: json['licensePlate'],
      maintenanceRecords: (json['maintenance_records'] as List)
          .map((record) => MaintenanceRecordModel.fromJson(record))
          .toList(),
      pdfManualGridFsId: json['pdf_manual_grid_fs_id'],
      logo: json['logo'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'brand': brand,
    'model': model,
    'year': year,
    'licensePlate': licensePlate,
    'maintenance_records': maintenanceRecords.map((record) => record.toJson()).toList(),
    'pdf_manual_grid_fs_id': pdfManualGridFsId,
    'logo': logo,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
} 