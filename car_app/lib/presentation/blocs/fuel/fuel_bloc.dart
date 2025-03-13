import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:car_app/domain/usecases/usecases.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'fuel_event.dart';
import 'fuel_state.dart';
import 'dart:math';

/// BLoC para gestionar la funcionalidad de combustible
class FuelBloc extends Bloc<FuelEvent, FuelState> {
  final GetGeneralFuelPrices _getGeneralFuelPrices;
  final GetNearbyStations _getNearbyStations;
  final GetFavoriteStations _getFavoriteStations;
  final AddFavoriteStation _addFavoriteStation;
  final RemoveFavoriteStation _removeFavoriteStation;
  final GetStationDetails _getStationDetails;
  final SearchStations _searchStations;
  final InitializeFuelRepository _initializeFuelRepository;
  
  // Variables para controlar el tiempo de caché
  DateTime? _lastGeneralPricesUpdate;
  DateTime? _lastFavoritesUpdate;
  DateTime? _lastNearbyStationsUpdate;
  
  // Duración de la caché (5 minutos)
  final Duration _cacheDuration = const Duration(minutes: 5);
  
  FuelBloc({
    required GetGeneralFuelPrices getGeneralFuelPrices,
    required GetNearbyStations getNearbyStations,
    required GetFavoriteStations getFavoriteStations,
    required AddFavoriteStation addFavoriteStation,
    required RemoveFavoriteStation removeFavoriteStation,
    required GetStationDetails getStationDetails,
    required SearchStations searchStations,
    required InitializeFuelRepository initializeFuelRepository,
  }) : 
    _getGeneralFuelPrices = getGeneralFuelPrices,
    _getNearbyStations = getNearbyStations,
    _getFavoriteStations = getFavoriteStations,
    _addFavoriteStation = addFavoriteStation,
    _removeFavoriteStation = removeFavoriteStation,
    _getStationDetails = getStationDetails,
    _searchStations = searchStations,
    _initializeFuelRepository = initializeFuelRepository,
    super(const FuelState.initial()) {
    on<LoadGeneralFuelPrices>(_onLoadGeneralFuelPrices);
    on<LoadNearbyStations>(_onLoadNearbyStations);
    on<LoadFavoriteStations>(_onLoadFavoriteStations);
    on<AddToFavorites>(_onAddToFavorites);
    on<RemoveFromFavorites>(_onRemoveFromFavorites);
    on<SelectStation>(_onSelectStation);
    on<ChangeFuelType>(_onChangeFuelType);
    on<ChangeSearchRadius>(_onChangeSearchRadius);
    on<SetUserLocation>(_onSetUserLocation);
    on<RefreshFuelData>(_onRefreshFuelData);
    on<SearchStationsEvent>(_onSearchStations);
    on<InitializeFuel>(_onInitializeFuel);
  }
  
  Future<void> _onInitializeFuel(
    InitializeFuel event,
    Emitter<FuelState> emit,
  ) async {
    await _initializeFuelRepository(event.token);
  }
  
  /// Maneja el evento para cargar los precios generales
  Future<void> _onLoadGeneralFuelPrices(
    LoadGeneralFuelPrices event,
    Emitter<FuelState> emit,
  ) async {
    // Verificar caché (si los datos ya existen y son recientes, no volver a cargar)
    if (state.generalPrices != null && 
        _lastGeneralPricesUpdate != null &&
        DateTime.now().difference(_lastGeneralPricesUpdate!) < _cacheDuration &&
        !event.forceRefresh) {
      return; // Usar datos en caché
    }
    
    emit(state.copyWith(
      status: FuelStatus.loading,
      isLoading: true,
      clearError: true,
    ));
    
    final result = await _getGeneralFuelPrices();
    
    result.fold(
      (failure) => emit(state.copyWith(
        status: FuelStatus.error,
        error: failure.message,
        isLoading: false,
      )),
      (prices) {
        _lastGeneralPricesUpdate = DateTime.now();
        emit(state.copyWith(
          status: FuelStatus.loadedPrices,
          generalPrices: prices,
          isLoading: false,
        ));
      },
    );
  }
  
  /// Maneja el evento para cargar estaciones cercanas
  Future<void> _onLoadNearbyStations(
    LoadNearbyStations event,
    Emitter<FuelState> emit,
  ) async {
    // Si ya estamos cargando y no es forzado, salir
    if (state.isLoading && !event.forceRefresh) {
      return;
    }

    // Iniciar carga
    emit(state.copyWith(
      isLoading: true,
      status: FuelStatus.loading,
      clearError: true,
    ));

    try {
      // Verificar si necesitamos obtener la ubicación
      double? lat = state.currentLatitude;
      double? lng = state.currentLongitude;

      if (lat == null || lng == null) {
        try {
          // Intentar obtener la ubicación usando la configuración recomendada
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          
          lat = position.latitude;
          lng = position.longitude;
          
          emit(state.copyWith(
            currentLatitude: lat,
            currentLongitude: lng,
          ));
        } catch (e) {
          // Usar coordenadas predeterminadas (Madrid)
          lat = 40.416775;
          lng = -3.703790;
          
          emit(state.copyWith(
            currentLatitude: lat,
            currentLongitude: lng,
            error: 'No se pudo obtener tu ubicación: $e',
          ));
        }
      }
      
      // Usar un radio mayor para la búsqueda inicial
      final radius = state.searchRadius ?? event.initialRadius;

      // Obtener estaciones cercanas - Usando un enfoque más simple
      final result = await _getNearbyStations.call(
        latitude: lat,
        longitude: lng,
        radius: radius,
        fuelType: state.selectedFuelType,
      );
      
      result.fold(
        (failure) => emit(state.copyWith(
          status: FuelStatus.error,
          error: failure.message,
          isLoading: false,
        )),
        (stations) => emit(state.copyWith(
          status: FuelStatus.loadedStations,
          nearbyStations: stations,
          isLoading: false,
          lastNearbyStationsUpdateTime: DateTime.now(),
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: FuelStatus.error,
        error: 'Error inesperado: $e',
        isLoading: false,
      ));
    }
  }
  
  /// Maneja el evento para cargar estaciones favoritas
  Future<void> _onLoadFavoriteStations(
    LoadFavoriteStations event,
    Emitter<FuelState> emit,
  ) async {
    // Verificar caché para favoritos
    if (state.favoriteStations.isNotEmpty && 
        _lastFavoritesUpdate != null &&
        DateTime.now().difference(_lastFavoritesUpdate!) < _cacheDuration &&
        !event.forceRefresh) {
      return; // Usar datos en caché
    }
    
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
    ));
    
    final result = await _getFavoriteStations();
    
    result.fold(
      (failure) => emit(state.copyWith(
        error: failure.message,
        isLoading: false,
      )),
      (stations) {
        _lastFavoritesUpdate = DateTime.now();
        emit(state.copyWith(
          status: FuelStatus.loadedFavorites,
          favoriteStations: stations,
          isLoading: false,
          lastFavoriteStationsUpdateTime: DateTime.now(),
        ));
      },
    );
  }
  
  /// Maneja el evento para buscar estaciones por texto
  Future<void> _onSearchStations(
    SearchStationsEvent event,
    Emitter<FuelState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
    ));
    
    final result = await _searchStations(event.query);
    
    result.fold(
      (failure) => emit(state.copyWith(
        error: failure.message,
        isLoading: false,
      )),
      (stations) => emit(state.copyWith(
        nearbyStations: stations, // Mostrar los resultados de búsqueda como estaciones cercanas
        isLoading: false,
      )),
    );
  }
  
  /// Maneja el evento para añadir una estación a favoritos
  Future<void> _onAddToFavorites(
    AddToFavorites event,
    Emitter<FuelState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
    ));
    
    final result = await _addFavoriteStation(event.stationId);
    
    result.fold(
      (failure) => emit(state.copyWith(
        error: failure.message,
        isLoading: false,
      )),
      (_) {
        // Actualizar estaciones cercanas marcando la añadida como favorita
        final updatedNearbyStations = state.nearbyStations.map((station) {
          if (station.id == event.stationId) {
            return station.toggleFavorite();
          }
          return station;
        }).toList();
        
        // Buscar la estación en las estaciones cercanas o en la estación seleccionada
        FuelStation? stationToAdd;
        
        // Intentar encontrar en las estaciones cercanas actualizadas
        for (var station in updatedNearbyStations) {
          if (station.id == event.stationId) {
            stationToAdd = station;
            break;
          }
        }
        
        // Si no la encontramos en las estaciones cercanas, revisar si es la estación seleccionada
        if (stationToAdd == null && 
            state.selectedStation != null && 
            state.selectedStation!.id == event.stationId) {
          stationToAdd = state.selectedStation!.toggleFavorite();
        }
        
        // Si tenemos una estación para añadir, actualizamos la lista de favoritos
        final updatedFavorites = List<FuelStation>.from(state.favoriteStations);
        if (stationToAdd != null) {
          // Añadir solo si no existe ya en los favoritos
          bool alreadyExists = false;
          for (var fav in updatedFavorites) {
            if (fav.id == stationToAdd.id) {
              alreadyExists = true;
              break;
            }
          }
          
          if (!alreadyExists) {
            updatedFavorites.add(stationToAdd);
          }
        }
        
        // Actualizar la estación seleccionada si corresponde
        FuelStation? updatedSelectedStation = state.selectedStation;
        if (state.selectedStation != null && state.selectedStation!.id == event.stationId) {
          updatedSelectedStation = state.selectedStation!.toggleFavorite();
        }
        
        emit(state.copyWith(
          nearbyStations: updatedNearbyStations,
          favoriteStations: updatedFavorites,
          selectedStation: updatedSelectedStation,
          isLoading: false,
        ));
      },
    );
  }
  
  /// Maneja el evento para eliminar una estación de favoritos
  Future<void> _onRemoveFromFavorites(
    RemoveFromFavorites event,
    Emitter<FuelState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
    ));
    
    final result = await _removeFavoriteStation(event.stationId);
    
    result.fold(
      (failure) => emit(state.copyWith(
        error: failure.message,
        isLoading: false,
      )),
      (_) {
        // Actualizar estaciones cercanas desmarcando la eliminada como favorita
        final updatedNearbyStations = state.nearbyStations.map((station) {
          if (station.id == event.stationId) {
            return station.toggleFavorite();
          }
          return station;
        }).toList();
        
        // Eliminar la estación de la lista de favoritos
        final updatedFavorites = state.favoriteStations
            .where((station) => station.id != event.stationId)
            .toList();
        
        // Actualizar la estación seleccionada si corresponde
        FuelStation? updatedSelectedStation = state.selectedStation;
        if (state.selectedStation != null && state.selectedStation!.id == event.stationId) {
          updatedSelectedStation = state.selectedStation!.toggleFavorite();
        }
        
        emit(state.copyWith(
          nearbyStations: updatedNearbyStations,
          favoriteStations: updatedFavorites,
          selectedStation: updatedSelectedStation,
          isLoading: false,
        ));
      },
    );
  }
  
  /// Maneja el evento para seleccionar una estación
  void _onSelectStation(
    SelectStation event,
    Emitter<FuelState> emit,
  ) {
    emit(state.copyWith(
      selectedStation: event.station,
      clearError: true,
    ));
  }
  
  /// Maneja el evento para cambiar el tipo de combustible
  void _onChangeFuelType(
    ChangeFuelType event,
    Emitter<FuelState> emit,
  ) {
    emit(state.copyWith(
      selectedFuelType: event.fuelType,
      clearError: true,
    ));
    
    // Recargar estaciones cercanas con el nuevo filtro
    if (state.currentLatitude != null && state.currentLongitude != null) {
      add(LoadNearbyStations(forceRefresh: true));
    }
  }
  
  /// Maneja el evento para cambiar el radio de búsqueda
  void _onChangeSearchRadius(
    ChangeSearchRadius event,
    Emitter<FuelState> emit,
  ) {
    emit(state.copyWith(
      searchRadius: event.radius,
      clearError: true,
    ));
    
    // Recargar estaciones cercanas con el nuevo radio
    if (state.currentLatitude != null && state.currentLongitude != null) {
      add(LoadNearbyStations(forceRefresh: true));
    }
  }
  
  /// Maneja el evento para establecer la ubicación del usuario
  void _onSetUserLocation(
    SetUserLocation event,
    Emitter<FuelState> emit,
  ) {
    emit(state.copyWith(
      currentLatitude: event.latitude,
      currentLongitude: event.longitude,
      clearError: true,
    ));
    
    // Recargar estaciones cercanas con la nueva ubicación
    add(LoadNearbyStations(forceRefresh: true));
  }
  
  /// Maneja el evento para actualizar todos los datos
  Future<void> _onRefreshFuelData(
    RefreshFuelData event,
    Emitter<FuelState> emit,
  ) async {
    // Actualizar precios generales
    add(const LoadGeneralFuelPrices(forceRefresh: true));
    
    // Actualizar favoritos
    add(const LoadFavoriteStations(forceRefresh: true));
    
    // Si tenemos coordenadas, actualizar estaciones cercanas
    if (state.currentLatitude != null && state.currentLongitude != null) {
      add(const LoadNearbyStations(forceRefresh: true));
    }
  }
} 