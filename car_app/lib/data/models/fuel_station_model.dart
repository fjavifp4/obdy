import '../../domain/entities/fuel_station.dart';

class FuelStationModel {
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
  final bool isFavorite;
  final DateTime lastUpdated;
  final double? distance;
  final String schedule;

  FuelStationModel({
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
    required this.lastUpdated,
    this.isFavorite = false,
    this.distance,
    required this.schedule,
  });

  factory FuelStationModel.fromJson(Map<String, dynamic> json) {
    // Procesar el mapa de precios que viene del backend
    final pricesJson = json['prices'] as Map<String, dynamic>? ?? {};
    final prices = <String, double>{};
    
    pricesJson.forEach((key, value) {
      if (value != null) {
        prices[key] = double.parse(value.toString());
      }
    });

    return FuelStationModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      latitude: double.parse((json['latitude'] ?? '0').toString()),
      longitude: double.parse((json['longitude'] ?? '0').toString()),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      prices: prices,
      isFavorite: json['is_favorite'] as bool? ?? false,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated'].toString()) 
          : DateTime.now(),
      distance: json['distance'] != null ? double.parse(json['distance'].toString()) : null,
      schedule: json['schedule']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'address': address,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'prices': prices,
      'is_favorite': isFavorite,
      'last_updated': lastUpdated.toIso8601String(),
      if (distance != null) 'distance': distance!.toString(),
      'schedule': schedule,
    };
  }

  FuelStation toEntity() {
    return FuelStation(
      id: id,
      name: name,
      brand: brand,
      latitude: latitude,
      longitude: longitude,
      address: address,
      city: city,
      province: province,
      postalCode: postalCode,
      prices: prices,
      isFavorite: isFavorite,
      lastUpdated: lastUpdated,
      distance: distance,
      schedule: schedule,
    );
  }

  factory FuelStationModel.fromEntity(FuelStation station) {
    return FuelStationModel(
      id: station.id,
      name: station.name,
      brand: station.brand,
      latitude: station.latitude,
      longitude: station.longitude,
      address: station.address,
      city: station.city,
      province: station.province,
      postalCode: station.postalCode,
      prices: station.prices,
      isFavorite: station.isFavorite,
      lastUpdated: station.lastUpdated,
      distance: station.distance,
      schedule: station.schedule,
    );
  }
} 
