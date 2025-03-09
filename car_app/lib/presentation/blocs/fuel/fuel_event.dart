import 'package:equatable/equatable.dart';
import 'package:car_app/domain/entities/fuel_station.dart';

/// Clase base para los eventos de combustible
abstract class FuelEvent extends Equatable {
  const FuelEvent();
  
  @override
  List<Object?> get props => [];
}

/// Evento para inicializar el repositorio de combustible
class InitializeFuel extends FuelEvent {
  final String token;
  
  const InitializeFuel(this.token);
  
  @override
  List<Object> get props => [token];
}

/// Evento para cargar los precios generales del combustible
class LoadGeneralFuelPrices extends FuelEvent {
  final bool forceRefresh;
  
  const LoadGeneralFuelPrices({this.forceRefresh = false});
  
  @override
  List<Object> get props => [forceRefresh];
}

/// Evento para cargar estaciones cercanas
class LoadNearbyStations extends FuelEvent {
  final bool forceRefresh;
  final double initialRadius; // Radio inicial para la búsqueda

  const LoadNearbyStations({
    this.forceRefresh = false,
    this.initialRadius = 20.0, // Por defecto, buscar en un radio más amplio de 20km
  });

  @override
  List<Object?> get props => [forceRefresh, initialRadius];
}

/// Evento para buscar estaciones por texto
class SearchStationsEvent extends FuelEvent {
  final String query;
  
  const SearchStationsEvent(this.query);
  
  @override
  List<Object> get props => [query];
}

/// Evento para cargar las estaciones favoritas
class LoadFavoriteStations extends FuelEvent {
  final bool forceRefresh;
  
  const LoadFavoriteStations({this.forceRefresh = false});
  
  @override
  List<Object> get props => [forceRefresh];
}

/// Evento para añadir una estación a favoritos
class AddToFavorites extends FuelEvent {
  final String stationId;
  
  const AddToFavorites(this.stationId);
  
  @override
  List<Object> get props => [stationId];
}

/// Evento para eliminar una estación de favoritos
class RemoveFromFavorites extends FuelEvent {
  final String stationId;
  
  const RemoveFromFavorites(this.stationId);
  
  @override
  List<Object> get props => [stationId];
}

/// Evento para marcar una estación como seleccionada
class SelectStation extends FuelEvent {
  final FuelStation station;
  
  const SelectStation(this.station);
  
  @override
  List<Object> get props => [station];
}

/// Evento para cambiar el tipo de combustible seleccionado (para filtros)
class ChangeFuelType extends FuelEvent {
  final String? fuelType;
  
  const ChangeFuelType(this.fuelType);
  
  @override
  List<Object?> get props => [fuelType];
}

/// Evento para cambiar el radio de búsqueda
class ChangeSearchRadius extends FuelEvent {
  final double radius;
  
  const ChangeSearchRadius(this.radius);
  
  @override
  List<Object> get props => [radius];
}

/// Evento para establecer la ubicación actual del usuario
class SetUserLocation extends FuelEvent {
  final double latitude;
  final double longitude;
  
  const SetUserLocation({
    required this.latitude,
    required this.longitude,
  });
  
  @override
  List<Object> get props => [latitude, longitude];
}

/// Evento para actualizar todo (precios, estaciones cercanas y favoritos)
class RefreshFuelData extends FuelEvent {
  const RefreshFuelData();
} 