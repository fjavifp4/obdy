import 'package:car_app/domain/repositories/chat_repository.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';

class InitializeRepositories {
  final VehicleRepository vehicleRepository;
  final ChatRepository chatRepository;

  InitializeRepositories({
    required this.vehicleRepository,
    required this.chatRepository,
  });

  Future<void> call(String token) async {
    await vehicleRepository.initialize(token);
    await chatRepository.initialize(token);
  }
} 