import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserStatistics extends HomeEvent {
  const LoadUserStatistics();
}

class LoadFuelPrices extends HomeEvent {
  const LoadFuelPrices();
}

class RefreshHomeData extends HomeEvent {
  const RefreshHomeData();
} 
