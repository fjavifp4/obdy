import 'package:equatable/equatable.dart';

abstract class ManualState extends Equatable {
  const ManualState();

  @override
  List<Object?> get props => [];
}

class ManualInitial extends ManualState {}

class ManualLoading extends ManualState {}

class ManualExists extends ManualState {
  final bool exists;
  const ManualExists(this.exists);

  @override
  List<Object> get props => [exists];
}

class ManualDownloaded extends ManualState {
  final List<int> fileBytes;
  const ManualDownloaded(this.fileBytes);

  @override
  List<Object> get props => [fileBytes];
}

class ManualDeleted extends ManualState {}

class ManualUpdated extends ManualState {}

class ManualError extends ManualState {
  final String message;
  const ManualError(this.message);

  @override
  List<Object> get props => [message];
} 