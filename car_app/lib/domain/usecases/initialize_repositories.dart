import 'package:car_app/domain/repositories/chat_repository.dart';
import 'package:car_app/domain/repositories/vehicle_repository.dart';
import 'package:car_app/domain/repositories/obd_repository.dart';

class InitializeRepositories {
  final VehicleRepository vehicleRepository;
  final ChatRepository chatRepository;
  final OBDRepository obdRepository;

  InitializeRepositories({
    required this.vehicleRepository,
    required this.chatRepository,
    required this.obdRepository,
  });

  Future<void> call(String token) async {
    await vehicleRepository.initialize(token);
    await chatRepository.initialize(token);
    await obdRepository.initialize();
  }
} 