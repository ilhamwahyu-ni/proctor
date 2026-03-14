import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Creates an [AppUser] from a Firestore document snapshot.
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      id: doc.id,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      role: UserRoleX.fromString(data['role'] as String),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
    );
  }

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

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.firestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

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
