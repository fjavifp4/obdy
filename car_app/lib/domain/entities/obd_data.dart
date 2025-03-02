// lib/domain/entities/obd_data.dart
class OBDData {
  final String pid;
  final double value;
  final String unit;
  final String description;

  OBDData({
    required this.pid,
    required this.value,
    required this.unit,
    required this.description,
  });
}