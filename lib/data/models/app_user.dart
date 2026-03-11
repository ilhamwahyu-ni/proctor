import 'package:proctor/data/models/user_role.dart';

/// User model used across the Proctor application.
class AppUser {
  /// Creates an immutable user model.
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.isActive,
  });

  /// Unique identifier of the user document.
  final String id;

  /// User email used for authentication.
  final String email;

  /// Human-readable display name.
  final String displayName;

  /// Current role assigned to the user.
  final UserRole role;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Whether the account is active.
  final bool isActive;

  /// Returns a copy of the user with updated fields.
  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
