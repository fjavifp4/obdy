import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/usecases/trip/get_user_statistics.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetUserStatistics getUserStatistics;

  HomeBloc({required this.getUserStatistics}) : super(const HomeState.initial()) {
    on<LoadUserStatistics>(_onLoadUserStatistics);
    on<LoadFuelPrices>(_onLoadFuelPrices);
    on<RefreshHomeData>(_onRefreshHomeData);
  }

  Future<void> _onLoadUserStatistics(
    LoadUserStatistics event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));

    // Verificar si el usuario está autenticado
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null || token.isEmpty) {
      emit(state.copyWith(
        status: HomeStatus.error,
        error: 'No ha iniciado sesión. Por favor, inicie sesión para ver sus estadísticas.',
      ));
      return;
    }

    final result = await getUserStatistics();

    result.fold(
      (failure) {
        // Si el error contiene algo sobre token o autenticación
        if (failure.message.toLowerCase().contains('token') || 
            failure.message.toLowerCase().contains('autent')) {
          emit(state.copyWith(
            status: HomeStatus.error,
            error: 'Se cerró la sesión. Por favor, vuelva a iniciar sesión.',
          ));
        } else {
          emit(state.copyWith(
            status: HomeStatus.error,
            error: failure.message,
          ));
        }
      },
      (statistics) => emit(state.copyWith(
        status: HomeStatus.loaded,
        statistics: statistics,
      )),
    );
  }

  Future<void> _onLoadFuelPrices(
    LoadFuelPrices event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isLoadingFuelPrices) return;

    emit(state.copyWith(isLoadingFuelPrices: true));

    try {
      // Esta es una API de ejemplo, deberías sustituirla por una real
      // Aquí usaríamos una API de precios de combustibles más adelante
      final response = await http.get(
        Uri.parse('https://mockapi.com/fuel-prices'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, double> fuelPrices = {
          'gasolina95': data['gasolina95'] ?? 0.0,
          'gasolina98': data['gasolina98'] ?? 0.0,
          'diesel': data['diesel'] ?? 0.0,
        };

        emit(state.copyWith(
          isLoadingFuelPrices: false,
          fuelPrices: fuelPrices,
        ));
      } else {
        // Por ahora, crearemos datos de ejemplo
        emit(state.copyWith(
          isLoadingFuelPrices: false,
          fuelPrices: {
            'gasolina95': 1.65,
            'gasolina98': 1.79,
            'diesel': 1.55,
          },
        ));
      }
    } catch (e) {
      // Por ahora, crearemos datos de ejemplo en caso de error
      emit(state.copyWith(
        isLoadingFuelPrices: false,
        fuelPrices: {
          'gasolina95': 1.65,
          'gasolina98': 1.79,
          'diesel': 1.55,
        },
      ));
    }
  }

  Future<void> _onRefreshHomeData(
    RefreshHomeData event,
    Emitter<HomeState> emit,
  ) async {
    add(const LoadUserStatistics());
    add(const LoadFuelPrices());
  }
} 
