abstract class Failure {
  final String message;
  const Failure(this.message);
}

class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message);
}

class OBDFailure extends Failure {
  const OBDFailure(String message) : super(message);
} 