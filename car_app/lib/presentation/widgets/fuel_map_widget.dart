import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_bloc.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_event.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_state.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'dart:math' as math;
import 'package:car_app/config/core/utils/maps_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_app/presentation/blocs/theme/theme_bloc.dart';

/// Widget que muestra un mapa con estaciones de combustible cercanas
class FuelMapWidget extends StatefulWidget {
  const FuelMapWidget({super.key});

  @override
  State<FuelMapWidget> createState() => _FuelMapWidgetState();
}

class _FuelMapWidgetState extends State<FuelMapWidget> {
  GoogleMapController? _mapController;
  bool _isMapInitialized = false;
  bool _locationRequested = false;
  bool _hasMapError = false;
  String? _mapErrorMessage;
  String? _selectedFuelType;
  double _searchRadius = 5.0;
  bool _isFilterExpanded = false;
  double? _maxPriceFilter;
  Set<Marker> _markers = {};
  LatLng _initialPosition = LatLng(0, 0);
  double _currentZoom = 10.0;
  static const String _zoomKey = 'map_zoom_level';
  static const String _latKey = 'map_latitude';
  static const String _lngKey = 'map_longitude';
  
  @override
  void initState() {
    super.initState();
    // Usar Future.microtask para evitar problemas con el build
    Future.microtask(() {
      if (mounted) {
        _checkLocationPermission();
        _loadMapPreferences();
      }
    });
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Cargar preferencias guardadas del mapa
  Future<void> _loadMapPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedZoom = prefs.getDouble(_zoomKey);
      final savedLat = prefs.getDouble(_latKey);
      final savedLng = prefs.getDouble(_lngKey);
      
      if (savedZoom != null && savedLat != null && savedLng != null) {
        setState(() {
          _currentZoom = savedZoom;
          _initialPosition = LatLng(savedLat, savedLng);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar preferencias del mapa: $e');
    }
  }

  // Guardar preferencias del mapa
  Future<void> _saveMapPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_zoomKey, _currentZoom);
      await prefs.setDouble(_latKey, _initialPosition.latitude);
      await prefs.setDouble(_lngKey, _initialPosition.longitude);
      debugPrint('Preferencias guardadas: zoom=$_currentZoom, lat=${_initialPosition.latitude}, lng=${_initialPosition.longitude}');
    } catch (e) {
      debugPrint('Error al guardar preferencias del mapa: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return BlocConsumer<FuelBloc, FuelState>(
      listenWhen: (previous, current) => 
        previous.error != current.error && current.error != null,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      buildWhen: (previous, current) =>
        previous.currentLatitude != current.currentLatitude ||
        previous.currentLongitude != current.currentLongitude ||
        previous.nearbyStations != current.nearbyStations ||
        previous.isLoading != current.isLoading,
      builder: (context, state) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estaciones cercanas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        if (state.isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(_isFilterExpanded 
                              ? Icons.filter_list_off 
                              : Icons.filter_list),
                          onPressed: () {
                            setState(() {
                              _isFilterExpanded = !_isFilterExpanded;
                            });
                          },
                          tooltip: 'Filtros',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isFilterExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo de combustible:', 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedFuelType,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos los tipos'),
                          ),
                          const DropdownMenuItem(
                            value: 'gasolina95',
                            child: Text('Gasolina 95'),
                          ),
                          const DropdownMenuItem(
                            value: 'gasolina98',
                            child: Text('Gasolina 98'),
                          ),
                          const DropdownMenuItem(
                            value: 'diesel',
                            child: Text('Diesel'),
                          ),
                          const DropdownMenuItem(
                            value: 'dieselPlus',
                            child: Text('Diesel Premium'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFuelType = value;
                          });
                          context.read<FuelBloc>().add(ChangeFuelType(value));
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Radio de búsqueda:', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text('${_searchRadius.toInt()} km',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _searchRadius,
                        min: 2.0,
                        max: 20.0,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() {
                            _searchRadius = value;
                          });
                        },
                        onChangeEnd: (value) {
                          context.read<FuelBloc>().add(ChangeSearchRadius(value));
                        },
                      ),
                      const SizedBox(height: 8),
                      // Nuevo: Filtro de precio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Precio máximo:', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(_maxPriceFilter != null ? '${_maxPriceFilter!.toStringAsFixed(3)} €/L' : 'Sin límite',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // Slider para el precio
                      Slider(
                        value: _maxPriceFilter ?? 2.5,
                        min: 1.0,
                        max: 2.5,
                        divisions: 30,
                        onChanged: (value) {
                          setState(() {
                            _maxPriceFilter = value;
                          });
                        },
                        onChangeEnd: (value) {
                          _applyFilters();
                        },
                      ),
                      // Botón para limpiar filtro de precio
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _maxPriceFilter = null;
                            });
                            _applyFilters();
                          },
                          child: const Text('Limpiar filtro de precio'),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: _buildMapContent(state, context, isDarkMode),
              ),
              // Nuevo: Lista de precios más bajos
              _buildBestPricesSection(state),
            ],
          ),
        );
      },
    );
  }

  // Nuevo: Sección de mejores precios
  Widget _buildBestPricesSection(FuelState state) {
    if (state.nearbyStations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No se encontraron estaciones cercanas',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    // Filtrar estaciones según tipo de combustible y precio
    final filteredStations = _getFilteredStations(state.nearbyStations);
    
    if (filteredStations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No hay estaciones que coincidan con los filtros',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    // Obtener las 3 estaciones con mejor precio para el tipo seleccionado
    final bestPriceStations = _getBestPriceStations(filteredStations, _selectedFuelType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Mejores precios ${_selectedFuelType != null ? 'de ${FuelTypes.getShortName(_selectedFuelType!)}' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...bestPriceStations.map((station) => _buildBestPriceCard(station)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Se encontraron ${filteredStations.length} estaciones',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Devuelve hasta 3 estaciones con los mejores precios
  List<FuelStation> _getBestPriceStations(List<FuelStation> stations, String? fuelType) {
    if (stations.isEmpty) return [];
    
    // Si no hay tipo específico, usamos gasolina95 como predeterminado
    final type = fuelType ?? 'gasolina95';
    
    // Filtrar estaciones que tienen precio para este tipo
    var stationsWithPrice = stations.where((s) => s.prices.containsKey(type)).toList();
    
    if (stationsWithPrice.isEmpty) {
      // Si no hay estaciones con este tipo, intentar con el primer tipo disponible
      if (stations.first.prices.isNotEmpty) {
        final availableType = stations.first.prices.keys.first;
        stationsWithPrice = stations.where((s) => s.prices.containsKey(availableType)).toList();
      } else {
        return [];
      }
    }
    
    // Ordenar por precio ascendente
    stationsWithPrice.sort((a, b) {
      final priceA = a.prices[type] ?? double.infinity;
      final priceB = b.prices[type] ?? double.infinity;
      return priceA.compareTo(priceB);
    });
    
    // Devolver las 3 mejores (o menos si hay menos)
    return stationsWithPrice.take(3).toList();
  }

  Widget _buildBestPriceCard(FuelStation station) {
    // Determinar qué tipo de combustible mostrar
    final fuelType = _selectedFuelType ?? 
        (station.prices.containsKey('gasolina95') ? 'gasolina95' : 
        station.prices.keys.first);
    
    final price = station.prices[fuelType];
    if (price == null) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getPriceColor(price).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${price.toStringAsFixed(2)}€',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: _getPriceColor(price),
              ),
            ),
          ),
        ),
        title: Text(
          '${station.brand} - ${station.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${station.address} - A ${station.distance?.toStringAsFixed(1) ?? "?"} km',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            station.isFavorite ? Icons.star : Icons.star_border,
            color: station.isFavorite ? Colors.amber : null,
          ),
          onPressed: () {
            if (station.isFavorite) {
              context.read<FuelBloc>().add(RemoveFromFavorites(station.id));
            } else {
              context.read<FuelBloc>().add(AddToFavorites(station.id));
            }
          },
        ),
        onTap: () => _showStationDetails(station),
      ),
    );
  }

  // Devuelve un color según el precio (verde para barato, rojo para caro)
  Color _getPriceColor(double price) {
    // Asumimos que 1.2 es muy barato y 2.0 es muy caro
    if (price < 1.4) return Colors.green.shade800;
    if (price < 1.6) return Colors.green.shade500;
    if (price < 1.8) return Colors.amber.shade700;
    if (price < 2.0) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  // Filtra las estaciones según tipo de combustible y precio máximo
  List<FuelStation> _getFilteredStations(List<FuelStation> stations) {
    var filteredStations = List<FuelStation>.from(stations);
    
    // Filtrar por tipo de combustible
    if (_selectedFuelType != null) {
      filteredStations = filteredStations
          .where((station) => station.prices.containsKey(_selectedFuelType))
          .toList();
    }
    
    // Filtrar por precio máximo
    if (_maxPriceFilter != null) {
      filteredStations = filteredStations.where((station) {
        if (_selectedFuelType != null) {
          final price = station.prices[_selectedFuelType];
          return price != null && price <= _maxPriceFilter!;
        } else {
          // Si no hay tipo seleccionado, verificar si algún precio cumple con el máximo
          return station.prices.values.any((price) => price <= _maxPriceFilter!);
        }
      }).toList();
    }
    
    return filteredStations;
  }
  
  void _applyFilters() {
    // Notificar al bloc sobre los filtros
    context.read<FuelBloc>().add(ChangeFuelType(_selectedFuelType));
    context.read<FuelBloc>().add(ChangeSearchRadius(_searchRadius));
    
    // Esto forzaría un rebuild para aplicar filtro de precio
    setState(() {});
  }
  
  Widget _buildMapContent(FuelState state, BuildContext context, bool isDarkMode) {
    // Si hay un error en el mapa
    if (_hasMapError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Error al cargar el mapa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_mapErrorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _mapErrorMessage!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasMapError = false;
                  _locationRequested = false;
                });
                _checkLocationPermission();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    
    // Si no tenemos ubicación
    if (state.currentLatitude == null || state.currentLongitude == null) {
      if (!_locationRequested) {
        _requestLocation();
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_disabled, size: 32, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Esperando ubicación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Necesitamos tu ubicación para mostrarte estaciones cercanas',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _requestLocation(),
              child: const Text('Activar ubicación'),
            ),
          ],
        ),
      );
    }
    
    // Si estamos cargando
    if (state.isLoading && state.nearbyStations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Intentar mostrar el mapa
    try {
      if (!_isMapInitialized) {
        _isMapInitialized = true;
      }
      
      // Filtrar estaciones según los criterios
      final filteredStations = _getFilteredStations(state.nearbyStations);
      
      _markers = _buildMarkers(filteredStations);
      
      // Solo actualizar la posición inicial si no tenemos una guardada
      if (_initialPosition.latitude == 0 && _initialPosition.longitude == 0) {
        _initialPosition = LatLng(state.currentLatitude!, state.currentLongitude!);
      }
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: _currentZoom,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (isDarkMode) {
                  controller.setMapStyle(_getDarkMapStyle());
                }
                // Solo ajustar a los marcadores si no tenemos una posición guardada
                if (_markers.isNotEmpty && _initialPosition.latitude == 0 && _initialPosition.longitude == 0) {
                  _fitMapToMarkers();
                }
              },
              onCameraMove: (position) {
                setState(() {
                  _currentZoom = position.zoom;
                  _initialPosition = position.target;
                });
                _saveMapPreferences();
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              mapToolbarEnabled: true,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              trafficEnabled: true,
              mapType: MapType.normal,
            ),
            
            // Mostrar el contador de estaciones en una posición que no obstruya los controles
            // Lo movemos a la esquina superior izquierda con un fondo transparente
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${state.nearbyStations.length} estaciones encontradas',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // En caso de error, mostrar un mensaje y no el mapa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasMapError = true;
            _mapErrorMessage = e.toString();
          });
        }
      });
      
      return const Center(child: CircularProgressIndicator());
    }
  }
  
  Set<Marker> _buildMarkers(List<FuelStation> stations) {
    // Limitar a 30 marcadores para mejor rendimiento
    final visibleStations = stations.take(30).toList();
    
    return visibleStations.map((station) {
      String snippet = '';
      try {
        if (_selectedFuelType != null && station.prices.containsKey(_selectedFuelType)) {
          final price = station.prices[_selectedFuelType];
          if (price != null) {
            snippet = '${FuelTypes.getShortName(_selectedFuelType!)}: ${price.toStringAsFixed(3)} €/L';
          }
        } else if (station.prices.containsKey('gasolina95')) {
          final price = station.prices['gasolina95'];
          if (price != null) {
            snippet = 'G95: ${price.toStringAsFixed(3)} €/L';
          }
        } else if (station.prices.containsKey('diesel')) {
          final price = station.prices['diesel'];
          if (price != null) {
            snippet = 'Diesel: ${price.toStringAsFixed(3)} €/L';
          }
        }
        
        if (snippet.isEmpty && station.prices.isNotEmpty) {
          // Si no se pudo obtener un precio específico pero hay precios, usar el primero
          final firstKey = station.prices.keys.first;
          final firstPrice = station.prices[firstKey];
          if (firstPrice != null) {
            snippet = '${FuelTypes.getShortName(firstKey)}: ${firstPrice.toStringAsFixed(3)} €/L';
          }
        }
      } catch (e) {
        // Si ocurre algún error al formatear precios, usar un mensaje genérico
        snippet = 'Ver detalles de precios';
      }
      
      return Marker(
        markerId: MarkerId(station.id),
        position: LatLng(station.latitude, station.longitude),
        infoWindow: InfoWindow(
          title: '${station.brand} - ${station.name}',
          snippet: snippet,
          onTap: () {
            _showStationDetails(station);
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          station.isFavorite 
              ? BitmapDescriptor.hueYellow 
              : BitmapDescriptor.hueRed,
        ),
        onTap: () {
          context.read<FuelBloc>().add(SelectStation(station));
        },
      );
    }).toSet();
  }
  
  void _showStationDetails(FuelStation station) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.brand,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          station.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón de favorito
                  IconButton(
                    icon: Icon(
                      station.isFavorite ? Icons.star : Icons.star_border,
                      color: station.isFavorite ? Colors.amber : null,
                      size: 32,
                    ),
                    onPressed: () {
                      if (station.isFavorite) {
                        context.read<FuelBloc>().add(RemoveFromFavorites(station.id));
                      } else {
                        context.read<FuelBloc>().add(AddToFavorites(station.id));
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${station.address}, ${station.city}, ${station.postalCode}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              if (station.schedule.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Horario: ${station.schedule}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
              if (station.distance != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'A ${station.distance?.toStringAsFixed(1) ?? "?"} km de distancia',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Precios',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: station.prices.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      title: Text(FuelTypes.getShortName(entry.key)),
                      trailing: Text(
                        '${entry.value.toStringAsFixed(3)} €/L',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text('Cómo llegar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                      ),
                      onPressed: () async {
                        final opened = await _openInGoogleMaps(station);
                        if (opened && context.mounted) {
                          Navigator.pop(context);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir la aplicación de mapas'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<bool> _openInGoogleMaps(FuelStation station) async {
    // Usar el utilitario de mapas para abrir Google Maps con la ubicación de la estación
    return MapsUtil.openMapsWithLocation(
      station.latitude, 
      station.longitude,
      name: '${station.brand} - ${station.name}',
    );
  }
  
  void _checkLocationPermission() async {
    if (mounted) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          // Los servicios de ubicación no están habilitados
          return;
        }
        
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
        
        if (permission == LocationPermission.whileInUse || 
            permission == LocationPermission.always) {
          _requestLocation();
        }
      } catch (e) {
        debugPrint('Error al verificar permisos: $e');
      }
    }
  }
  
  void _requestLocation() {
    _locationRequested = true;
    
    if (!mounted) return;
    
    // Usar FuelBloc para solicitar ubicación
    final fuelBloc = context.read<FuelBloc>();
    final currentState = fuelBloc.state;
    
    if (currentState.currentLatitude == null || 
        currentState.currentLongitude == null) {
      fuelBloc.add(const LoadNearbyStations());
    }
  }

  void _fitMapToMarkers() {
    if (_mapController != null && _markers.isNotEmpty) {
      // Calcular los límites (bounds) basados en todas las posiciones de los marcadores
      final bounds = _calculateBounds(_markers.map((marker) => marker.position).toList());
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          50.0, // padding
        ),
      );
    }
  }
  
  LatLngBounds _calculateBounds(List<LatLng> positions) {
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;
    
    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _getDarkMapStyle() {
    return '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1a1a1a"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "lightness": -80
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9ca5b3"
          }
        ]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#263c3f"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#6b9a76"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#38414e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#212a37"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9ca5b3"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#1f2835"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#f3d19c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#515c6d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "lightness": -20
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3a3a3a"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#5a5a5a"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4a4a4a"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3a3a3a"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2f3548"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2f3548"
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c3238"
          }
        ]
      },
      {
        "featureType": "landscape.natural",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2c3238"
          }
        ]
      }
    ]
    ''';
  }
} 