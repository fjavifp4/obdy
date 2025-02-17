import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import 'package:car_app/domain/entities/chat.dart';
import 'package:car_app/domain/repositories/chat_repository.dart';

class CreateChat {
  final ChatRepository repository;

  CreateChat(this.repository);

  Future<Either<Failure, Chat>> call(String message, String vehicleId) async {
    try {
      final chat = await repository.createChat(message, vehicleId: vehicleId);
      return Either.right(chat);
    } catch (e) {
      return Either.left(AuthFailure(e.toString()));
    }
  }
} 