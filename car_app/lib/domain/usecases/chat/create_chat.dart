import 'package:obdy/config/core/either.dart';
import 'package:obdy/config/core/failures.dart';
import 'package:obdy/domain/entities/chat.dart';
import 'package:obdy/domain/repositories/chat_repository.dart';

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
