import 'package:car_app/core/either.dart';
import 'package:car_app/core/failures.dart';
import '../../entities/obd_data.dart';
import '../../repositories/obd_repository.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

class GetParameterData {
  final OBDRepository repository;

  GetParameterData(this.repository);

  Stream<Either<Failure, OBDData>> call(String pid) {
    try {
      return repository.getParameterData(pid)
          .map((data) => Either<Failure, OBDData>.right(data))
          .onErrorReturnWith((error, stackTrace) => 
              Either.left(OBDFailure('Error al obtener datos OBD: ${error.toString()}')));
    } catch (e) {
      return Stream.value(Either.left(OBDFailure('Error al iniciar stream OBD: ${e.toString()}')));
    }
  }
}