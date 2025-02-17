class User {
  final String id;
  final String email;
  final String username;
  final String token;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
  });
} 