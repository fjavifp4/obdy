import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_bloc.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_event.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_state.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'package:car_app/core/utils/maps_util.dart';

/// Widget que muestra estaciones de combustible cercanas y favoritas
class FuelStationsWidget extends StatefulWidget {
  const FuelStationsWidget({Key? key}) : super(key: key);

  @override
  State<FuelStationsWidget> createState() => _FuelStationsWidgetState();
}

class _FuelStationsWidgetState extends State<FuelStationsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoogleMapController? _mapController;
  String? _selectedFuelType;
  double _searchRadius = 5.0;
  bool _favoritesLoaded = false;
  bool _locationRequested = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FuelBloc, FuelState>(
      listenWhen: (previous, current) => previous.error != current.error && current.error != null,
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
      // Reduce rebuilds by only rebuilding when relevant data changes
      buildWhen: (previous, current) =>
        previous.favoriteStations != current.favoriteStations ||
        previous.nearbyStations != current.nearbyStations ||
        previous.isLoading != current.isLoading ||
        previous.currentLatitude != current.currentLatitude ||
        previous.currentLongitude != current.currentLongitude ||
        previous.selectedStation != current.selectedStation,
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
                child: Text(
                  state.favoriteStations.isNotEmpty 
                      ? 'Tus estaciones de combustible'
                      : 'Estaciones de combustible cercanas',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Favoritas'),
                  Tab(text: 'Mapa'),
                ],
                onTap: (index) {
                  // Load appropriate data when tab changes
                  if (index == 0 && !_favoritesLoaded && state.favoriteStations.isEmpty) {
                    _loadFavorites();
                  } else if (index == 1 && !_locationRequested && (state.currentLatitude == null || state.currentLongitude == null)) {
                    _requestLocation();
                  }
                },
              ),
              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFavoritesTab(state),
                    _buildMapTab(state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _loadFavorites() {
    _favoritesLoaded = true;
    // Use Future.microtask to avoid build-time setState
    Future.microtask(() {
      if (mounted) {
        context.read<FuelBloc>().add(const LoadFavoriteStations());
      }
    });
  }
  
  void _requestLocation() {
    _locationRequested = true;
    // Use Future.microtask to avoid build-time setState
    Future.microtask(() {
      if (mounted) {
        context.read<FuelBloc>().add(const LoadNearbyStations());
      }
    });
  }
  
  Widget _buildFavoritesTab(FuelState state) {
    // Solo cargar favoritos si están vacíos y aún no se ha solicitado la carga
    if (state.favoriteStations.isEmpty && !state.isLoading && !_favoritesLoaded) {
      _loadFavorites();
    }
    
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state.favoriteStations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tienes estaciones favoritas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Añade estaciones a favoritos para verlas aquí',
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(1); // Cambiar a la pestaña del mapa
                if (state.nearbyStations.isEmpty || 
                    state.currentLatitude == null || 
                    state.currentLongitude == null) {
                  _requestLocation();
                }
              },
              icon: const Icon(Icons.map),
              label: const Text('Explorar estaciones'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: state.favoriteStations.length,
      itemBuilder: (context, index) {
        final station = state.favoriteStations[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.local_gas_station,
                  color: Colors.amber,
                ),
              ),
            ),
            title: Text(
              '${station.brand} - ${station.name}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station.address),
                if (station.prices.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.euro, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      if (station.prices.containsKey('gasolina95'))
                        Text(
                          'G95: ${station.prices['gasolina95']!.toStringAsFixed(3)} €',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (station.prices.containsKey('diesel'))
                        Text(
                          'Diésel: ${station.prices['diesel']!.toStringAsFixed(3)} €',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.map_outlined),
              onPressed: () {
                if (state.currentLatitude != null && state.currentLongitude != null) {
                  // Centrar el mapa en esta estación
                  _tabController.animateTo(1); // Cambiar a la pestaña del mapa
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(station.latitude, station.longitude),
                      15,
                    ),
                  );
                  // Seleccionar la estación
                  context.read<FuelBloc>().add(SelectStation(station));
                }
              },
            ),
            onTap: () {
              _showStationDetails(context, station);
            },
          ),
        );
      },
    );
  }
  
  Widget _buildMapTab(FuelState state) {
    // Solo solicitar ubicación si no la tenemos y aún no se ha solicitado
    if ((state.currentLatitude == null || state.currentLongitude == null) && 
        !state.isLoading && 
        !_locationRequested) {
      _requestLocation();
    }
    
    if (state.isLoading && (state.currentLatitude == null || state.currentLongitude == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state.currentLatitude == null || state.currentLongitude == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Necesitamos tu ubicación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Habilita el acceso a la ubicación para ver estaciones cercanas',
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _requestLocation();
              },
              icon: const Icon(Icons.location_searching),
              label: const Text('Obtener ubicación'),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(state.currentLatitude!, state.currentLongitude!),
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          markers: _buildMarkers(state),
          onMapCreated: (controller) {
            setState(() {
              _mapController = controller;
            });
          },
        ),
        
        // Panel de filtros
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterDialog(context);
              },
              tooltip: 'Filtrar estaciones',
            ),
          ),
        ),
        
        // Indicador de carga
        if (state.isLoading)
          const Positioned(
            top: 8,
            left: 8,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          
        // Contador de estaciones
        if (state.nearbyStations.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: Card(
              color: Colors.white.withOpacity(0.8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '${state.nearbyStations.length} estaciones',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Set<Marker> _buildMarkers(FuelState state) {
    final Set<Marker> markers = {};
    
    for (final station in state.nearbyStations) {
      final String selectedFuelTypePrice = _selectedFuelType != null &&
                                         station.prices.containsKey(_selectedFuelType)
          ? 'Precio: ${station.prices[_selectedFuelType]?.toStringAsFixed(3) ?? 'N/A'} €/L'
          : '';
      
      markers.add(
        Marker(
          markerId: MarkerId(station.id),
          position: LatLng(station.latitude, station.longitude),
          infoWindow: InfoWindow(
            title: '${station.brand} - ${station.name}',
            snippet: selectedFuelTypePrice,
            onTap: () {
              _showStationDetails(context, station);
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            station.isFavorite ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed,
          ),
          onTap: () {
            context.read<FuelBloc>().add(SelectStation(station));
          },
        ),
      );
    }
    
    return markers;
  }
  
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtrar estaciones'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de combustible:'),
                    DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedFuelType,
                      hint: const Text('Todos'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...FuelTypes.allTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(FuelTypes.getShortName(type)),
                        )).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedFuelType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Radio de búsqueda:'),
                    Slider(
                      value: _searchRadius,
                      min: 1.0,
                      max: 20.0,
                      divisions: 19,
                      label: '${_searchRadius.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setState(() {
                          _searchRadius = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    
                    // Aplicar filtros
                    if (BlocProvider.of<FuelBloc>(context).state.currentLatitude != null) {
                      context.read<FuelBloc>().add(ChangeFuelType(_selectedFuelType));
                      context.read<FuelBloc>().add(ChangeSearchRadius(_searchRadius));
                    }
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showStationDetails(BuildContext context, FuelStation station) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                          'A ${station.distance!.toStringAsFixed(1)} km de distancia',
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
                    child: station.prices.isEmpty
                        ? const Center(child: Text('No hay información de precios disponible'))
                        : ListView(
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
                            final opened = await _openMapsApp(station);
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
      },
    );
  }
  
  Future<bool> _openMapsApp(FuelStation station) async {
    // Usar el utilitario de mapas para abrir Google Maps con la ubicación de la estación
    return MapsUtil.openMapsWithLocation(
      station.latitude, 
      station.longitude,
      name: '${station.brand} - ${station.name}',
    );
  }
} 