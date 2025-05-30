import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obdy/presentation/blocs/blocs.dart';
import 'package:obdy/domain/entities/trip.dart';
import 'package:intl/intl.dart';

class TripMapSection extends StatefulWidget {
  final String vehicleId;

  const TripMapSection({
    super.key,
    required this.vehicleId,
  });

  @override
  State<TripMapSection> createState() => _TripMapSectionState();
}

class _TripMapSectionState extends State<TripMapSection> {
  GoogleMapController? _mapController;
  int _selectedTripIndex = 0;
  List<Trip> _recentTrips = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isMapReady = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripBloc, TripState>(
      builder: (context, state) {
        // Obtener los viajes recientes del vehicleStats
        if (state.vehicleStats != null) {
          _recentTrips = state.vehicleStats!.recentTrips;
        }

        // Si no hay viajes, mostrar un mensaje
        if (_recentTrips.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No hay viajes registrados para este vehículo'),
              ),
            ),
          );
        }

        // Asegurarse de que el índice seleccionado sea válido
        if (_selectedTripIndex >= _recentTrips.length) {
          _selectedTripIndex = 0;
        }

        // Obtener el viaje seleccionado
        final selectedTrip = _recentTrips[_selectedTripIndex];

        // Actualizar polylines y markers
        _updateMapElements(selectedTrip);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de la sección
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recorridos de viajes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Selector de viajes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelText: 'Seleccionar viaje',
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  value: _selectedTripIndex,
                  items: List.generate(_recentTrips.length, (index) {
                    final trip = _recentTrips[index];
                    final date = DateFormat('dd/MM/yyyy HH:mm').format(trip.startTime);
                    return DropdownMenuItem(
                      value: index,
                      child: Text(
                        'Viaje ${index + 1} - $date',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedTripIndex = value;
                      });
                    }
                  },
                ),
              ),

              // Mapa
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 250,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _getInitialMapPosition(selectedTrip),
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        setState(() {
                          _mapController = controller;
                          _isMapReady = true;
                        });
                        
                        final isDarkMode = context.read<ThemeBloc>().state;
                        if (isDarkMode) {
                          _setMapDarkMode(controller);
                        }
                        
                        _fitMapToRoute(selectedTrip);
                      },
                      polylines: _polylines,
                      markers: _markers,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationEnabled: false,
                      compassEnabled: true,
                    ),
                  ),
                ),
              ),

              // Estadísticas del viaje
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTripStats(selectedTrip),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateMapElements(Trip trip) {
    if (trip.gpsPoints.isEmpty) {
      _polylines = {};
      _markers = {};
      return;
    }

    // Crear polyline a partir de los puntos GPS
    final List<LatLng> points = trip.gpsPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Theme.of(context).colorScheme.primary,
        width: 5,
      ),
    };

    // Crear marcadores para el inicio y fin del recorrido
    _markers = {
      if (points.isNotEmpty)
        Marker(
          markerId: const MarkerId('start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Inicio',
            snippet: DateFormat('HH:mm:ss').format(trip.startTime),
          ),
        ),
      if (points.length > 1)
        Marker(
          markerId: const MarkerId('end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Fin',
            snippet: trip.endTime != null 
                ? DateFormat('HH:mm:ss').format(trip.endTime!) 
                : 'En progreso',
          ),
        ),
    };

    // Si el mapa ya está listo, ajustar la vista
    if (_isMapReady && _mapController != null) {
      _fitMapToRoute(trip);
    }
  }

  LatLng _getInitialMapPosition(Trip trip) {
    if (trip.gpsPoints.isEmpty) {
      // Posición por defecto si no hay puntos
      return const LatLng(40.416775, -3.703790); // Madrid
    }
    
    // Si hay puntos, usar el punto medio del recorrido
    if (trip.gpsPoints.length > 1) {
      final middleIndex = trip.gpsPoints.length ~/ 2;
      return LatLng(
        trip.gpsPoints[middleIndex].latitude,
        trip.gpsPoints[middleIndex].longitude,
      );
    }
    
    // Si solo hay un punto, usarlo
    return LatLng(
      trip.gpsPoints[0].latitude, 
      trip.gpsPoints[0].longitude
    );
  }

  void _fitMapToRoute(Trip trip) {
    if (trip.gpsPoints.isEmpty || _mapController == null) return;

    List<LatLng> points = trip.gpsPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    if (points.isEmpty) return;

    // Calcular los límites
    LatLngBounds bounds = _calculateBounds(points);

    // Ajustar la cámara a los límites con padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
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

  Widget _buildTripStats(Trip trip) {
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    // Formatear fecha y hora
    final startDate = DateFormat('dd/MM/yyyy').format(trip.startTime);
    final startTime = DateFormat('HH:mm').format(trip.startTime);
    final endTime = trip.endTime != null 
        ? DateFormat('HH:mm').format(trip.endTime!) 
        : 'En progreso';
    
    // Formatear duración
    String durationText = '';
    if (trip.durationSeconds > 0) {
      final hours = trip.durationSeconds ~/ 3600;
      final minutes = (trip.durationSeconds % 3600) ~/ 60;
      final seconds = trip.durationSeconds % 60;
      
      if (hours > 0) {
        durationText = '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        durationText = '${minutes}m ${seconds}s';
      } else {
        durationText = '${seconds}s';
      }
    } else {
      durationText = 'N/A';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas del viaje',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.calendar_today,
                label: 'Fecha',
                value: startDate,
                color: isDarkMode ? Colors.blueAccent : Colors.blue,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.access_time,
                label: 'Hora',
                value: '$startTime - $endTime',
                color: isDarkMode ? Colors.purpleAccent : Colors.purple,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.timer,
                label: 'Duración',
                value: durationText,
                color: isDarkMode ? Colors.amber : Colors.orange,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.map,
                label: 'Distancia',
                value: '${trip.distanceInKm.toStringAsFixed(2)} km',
                color: isDarkMode ? Colors.lightGreen : Colors.green,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.speed,
                label: 'Vel. media',
                value: '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h',
                color: isDarkMode ? Colors.tealAccent : Colors.teal,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.local_gas_station,
                label: 'Combustible',
                value: '${trip.fuelConsumptionLiters.toStringAsFixed(2)} L',
                color: isDarkMode ? Colors.redAccent : Colors.red,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        if (trip.fuelConsumptionLiters > 0 && trip.distanceInKm > 0) 
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.eco,
                  label: 'Consumo',
                  value: '${(trip.fuelConsumptionLiters / trip.distanceInKm * 100).toStringAsFixed(2)} L/100km',
                  color: isDarkMode ? Colors.green.shade300 : Colors.green.shade800,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.place,
                  label: 'Puntos GPS',
                  value: '${trip.gpsPoints.length}',
                  color: isDarkMode ? Colors.blueAccent : Colors.blue,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Theme.of(context).colorScheme.surfaceVariant
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.5 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode 
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _setMapDarkMode(GoogleMapController controller) {
    controller.setMapStyle('''
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
      }
    ]
    ''');
  }
}
