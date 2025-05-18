import 'package:equatable/equatable.dart';

/// Modelo para una estación de combustible
class FuelStation extends Equatable {
  final String id;
  final String name;
  final String brand;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String province;
  final String postalCode;
  final Map<String, double> prices;
  final String schedule;
  final double? distance; // Distancia en kilómetros desde la ubicación actual 
  final bool isFavorite;
  final DateTime lastUpdated;

  const FuelStation({
    required this.id,
    required this.name,
    required this.brand,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.prices,
    required this.schedule,
    this.distance,
    this.isFavorite = false,
    required this.lastUpdated,
  });

  /// Crea una copia de la estación con el estado de favorito invertido
  FuelStation toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }

  /// Crea una copia de la estación con algunos campos modificados
  FuelStation copyWith({
    String? id,
    String? name,
    String? brand,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    Map<String, double>? prices,
    String? schedule,
    double? distance,
    bool? isFavorite,
    DateTime? lastUpdated,
  }) {
    return FuelStation(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      prices: prices ?? this.prices,
      schedule: schedule ?? this.schedule,
      distance: distance ?? this.distance,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
    id, 
    name, 
    brand, 
    latitude, 
    longitude, 
    address, 
    city, 
    province, 
    postalCode, 
    prices, 
    schedule, 
    distance, 
    isFavorite, 
    lastUpdated
  ];

  /// Factorías adicionales
  factory FuelStation.fromJson(Map<String, dynamic> json) {
    return FuelStation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postal_code'] ?? '',
      prices: Map<String, double>.from(json['prices'] ?? {}),
      schedule: json['schedule'] ?? '',
      distance: json['distance'],
      isFavorite: json['is_favorite'] ?? false,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'prices': prices,
      'schedule': schedule,
      'distance': distance,
      'is_favorite': isFavorite,
    };
  }
}

/// Tipos de combustible comunes en España
class FuelTypes {
  static const String gasolina95 = 'Gasolina 95 E5';
  static const String gasolina95Premium = 'Gasolina 95 E5 Premium';
  static const String gasolina98 = 'Gasolina 98 E5';
  static const String diesel = 'Gasóleo A';
  static const String dieselPremium = 'Gasóleo Premium';
  static const String biodiesel = 'Biodiesel';
  static const String autogas = 'Gases licuados del petróleo';
  
  /// Lista con todos los tipos de combustible disponibles
  static const List<String> allTypes = [
    gasolina95, gasolina95Premium, gasolina98, 
    diesel, dieselPremium, biodiesel, autogas
  ];
  
  /// Obtiene una versión corta del nombre del combustible para mostrar en UI
  static String getShortName(String fuelType) {
    switch (fuelType) {
      case gasolina95: return 'Gasolina 95';
      case gasolina95Premium: return 'Gasolina 95+';
      case gasolina98: return 'Gasolina 98';
      case diesel: return 'Diesel';
      case dieselPremium: return 'Diesel+';
      case biodiesel: return 'Biodiesel';
      case autogas: return 'GLP';
      default: return fuelType;
    }
  }
} 