import 'package:equatable/equatable.dart';
import '../../../domain/usecases/trip/get_user_statistics.dart';

enum HomeStatus {
  initial,
  loading,
  loaded,
  error,
}

class HomeState extends Equatable {
  final HomeStatus status;
  final UserStatistics? statistics;
  final String? error;
  final bool isLoadingFuelPrices;
  final Map<String, double>? fuelPrices;

  const HomeState({
    required this.status,
    this.statistics,
    this.error,
    this.isLoadingFuelPrices = false,
    this.fuelPrices,
  });

  const HomeState.initial()
      : status = HomeStatus.initial,
        statistics = null,
        error = null,
        isLoadingFuelPrices = false,
        fuelPrices = null;

  HomeState copyWith({
    HomeStatus? status,
    UserStatistics? statistics,
    String? error,
    bool? isLoadingFuelPrices,
    Map<String, double>? fuelPrices,
  }) {
    return HomeState(
      status: status ?? this.status,
      statistics: statistics ?? this.statistics,
      error: error,
      isLoadingFuelPrices: isLoadingFuelPrices ?? this.isLoadingFuelPrices,
      fuelPrices: fuelPrices ?? this.fuelPrices,
    );
  }

  @override
  List<Object?> get props => [status, statistics, error, isLoadingFuelPrices, fuelPrices];
} 
