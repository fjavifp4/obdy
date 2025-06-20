import './maintenance_record.dart';

class Vehicle {
  final String id;
  final String userId;
  final String brand;
  final String model;
  final int year;
  final String licensePlate;
  final int? currentKilometers;
  final List<MaintenanceRecord> maintenanceRecords;
  final String? pdfManualGridFsId;
  final String? logo;
  final DateTime? lastItvDate;
  final DateTime? nextItvDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.currentKilometers,
    required this.maintenanceRecords,
    this.pdfManualGridFsId,
    this.logo,
    this.lastItvDate,
    this.nextItvDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasManual => pdfManualGridFsId != null;
  bool get hasLogo => logo != null && logo!.isNotEmpty;
  bool get hasLastItv => lastItvDate != null;
  bool get hasNextItv => nextItvDate != null;
} 
