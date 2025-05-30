import 'package:equatable/equatable.dart';
import 'package:obdy/domain/entities/fuel_station.dart';

/// Estados posibles para la funcionalidad de combustible
enum FuelStatus {
  initial,        // Estado inicial
  loading,        // Cargando datos
  loadedPrices,   // Precios generales cargados
  loadedStations, // Estaciones cercanas cargadas
  loadedFavorites,// Favoritos cargados
  error,          // Error
}

/// Estado del BLoC de combustible
class FuelState extends Equatable {
  final bool isLoading;
  final String? error;
  final Map<String, double>? generalPrices;
  final List<FuelStation> nearbyStations;
  final List<FuelStation> favoriteStations;
  final List<FuelStation> searchResults;
  final FuelStation? selectedStation;
  final double? currentLatitude;
  final double? currentLongitude;
  final FuelStatus status;
  final String? selectedFuelType;
  final double? searchRadius;
  final DateTime? lastGeneralPricesUpdateTime;
  final DateTime? lastFavoriteStationsUpdateTime;
  final DateTime? lastNearbyStationsUpdateTime;
  
  /// Constructor del estado de combustible
  const FuelState({
    this.isLoading = false,
    this.error,
    this.generalPrices,
    this.nearbyStations = const [],
    this.favoriteStations = const [],
    this.searchResults = const [],
    this.selectedStation,
    this.currentLatitude,
    this.currentLongitude,
    this.status = FuelStatus.initial,
    this.selectedFuelType,
    this.searchRadius = 5.0,
    this.lastGeneralPricesUpdateTime,
    this.lastFavoriteStationsUpdateTime,
    this.lastNearbyStationsUpdateTime,
  });
  
  /// Estado inicial
  const FuelState.initial() : 
    isLoading = false,
    error = null,
    generalPrices = null,
    nearbyStations = const [],
    favoriteStations = const [],
    searchResults = const [],
    selectedStation = null,
    currentLatitude = null,
    currentLongitude = null,
    status = FuelStatus.initial,
    selectedFuelType = null,
    searchRadius = 5.0,
    lastGeneralPricesUpdateTime = null,
    lastFavoriteStationsUpdateTime = null,
    lastNearbyStationsUpdateTime = null;
  
  /// Crea una copia del estado con algunos campos modificados
  FuelState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<String, double>? generalPrices,
    List<FuelStation>? nearbyStations,
    List<FuelStation>? favoriteStations,
    List<FuelStation>? searchResults,
    FuelStation? selectedStation,
    double? currentLatitude,
    double? currentLongitude,
    FuelStatus? status,
    String? selectedFuelType,
    double? searchRadius,
    DateTime? lastGeneralPricesUpdateTime,
    DateTime? lastFavoriteStationsUpdateTime,
    DateTime? lastNearbyStationsUpdateTime,
  }) {
    return FuelState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      generalPrices: generalPrices ?? this.generalPrices,
      nearbyStations: nearbyStations ?? this.nearbyStations,
      favoriteStations: favoriteStations ?? this.favoriteStations,
      searchResults: searchResults ?? this.searchResults,
      selectedStation: selectedStation ?? this.selectedStation,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      status: status ?? this.status,
      selectedFuelType: selectedFuelType ?? this.selectedFuelType,
      searchRadius: searchRadius ?? this.searchRadius,
      lastGeneralPricesUpdateTime: lastGeneralPricesUpdateTime ?? this.lastGeneralPricesUpdateTime,
      lastFavoriteStationsUpdateTime: lastFavoriteStationsUpdateTime ?? this.lastFavoriteStationsUpdateTime,
      lastNearbyStationsUpdateTime: lastNearbyStationsUpdateTime ?? this.lastNearbyStationsUpdateTime,
    );
  }
  
  @override
  List<Object?> get props => [
    isLoading,
    error,
    generalPrices,
    nearbyStations,
    favoriteStations,
    searchResults,
    selectedStation,
    currentLatitude,
    currentLongitude,
    status,
    selectedFuelType,
    searchRadius,
    lastGeneralPricesUpdateTime,
    lastFavoriteStationsUpdateTime,
    lastNearbyStationsUpdateTime,
  ];
} 
