import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_bloc.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_event.dart';
import 'package:car_app/presentation/blocs/fuel/fuel_state.dart';
import 'package:car_app/domain/entities/fuel_station.dart';
import 'package:car_app/config/core/utils/maps_util.dart';

/// Widget que muestra solo las estaciones de combustible favoritas
class FuelFavoritesWidget extends StatefulWidget {
  const FuelFavoritesWidget({super.key});

  @override
  State<FuelFavoritesWidget> createState() => _FuelFavoritesWidgetState();
}

class _FuelFavoritesWidgetState extends State<FuelFavoritesWidget> {
  bool _favoritesLoaded = false;
  
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
      // Reducir reconstrucciones innecesarias
      buildWhen: (previous, current) =>
        previous.favoriteStations != current.favoriteStations ||
        previous.isLoading != current.isLoading,
      builder: (context, state) {
        // Solo cargar favoritos si están vacíos y aún no se ha solicitado la carga
        if (state.favoriteStations.isEmpty && !state.isLoading && !_favoritesLoaded) {
          _loadFavorites();
        }
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estaciones favoritas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (state.isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            context.read<FuelBloc>().add(const LoadFavoriteStations(forceRefresh: true));
                          },
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Actualizar favoritas',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFavoritesList(state),
              ],
            ),
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
  
  Widget _buildFavoritesList(FuelState state) {
    if (state.isLoading && state.favoriteStations.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (state.favoriteStations.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_border, size: 32, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'No tienes estaciones favoritas',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.favoriteStations.length > 3 
          ? 3 
          : state.favoriteStations.length,
      itemBuilder: (context, index) {
        final station = state.favoriteStations[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.local_gas_station,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
            ),
            title: Text(
              '${station.brand} - ${station.name}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.address,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (station.prices.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (station.prices.containsKey('gasolina95'))
                        _buildPriceTag(
                          'G95: ${station.prices['gasolina95']!.toStringAsFixed(3)} €',
                          Colors.green[700]!,
                        ),
                      const SizedBox(width: 4),
                      if (station.prices.containsKey('diesel'))
                        _buildPriceTag(
                          'Diésel: ${station.prices['diesel']!.toStringAsFixed(3)} €',
                          Colors.amber[900]!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.map_outlined, size: 18),
              onPressed: () {
                // Enfoca el mapa en esta estación específica
                if (state.currentLatitude != null && state.currentLongitude != null) {
                  context.read<FuelBloc>().add(SelectStation(station));
                }
              },
            ),
            onTap: () {
              _showStationDetails(station);
            },
          ),
        );
      },
    );
  }
  
  Widget _buildPriceTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
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
                        final opened = await _openMapsWithLocation(station);
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
  
  Future<bool> _openMapsWithLocation(FuelStation station) async {
    // Usar el utilitario de mapas para abrir Google Maps con la ubicación de la estación
    return MapsUtil.openMapsWithLocation(
      station.latitude, 
      station.longitude,
      name: '${station.brand} - ${station.name}',
    );
  }
} 