/// Role types supported by the Proctor application.
enum UserRole { superAdmin, proctor, pending }

/// Readable labels and routing helpers for [UserRole].
extension UserRoleX on UserRole {
  /// Returns a human-readable label for the role.
  String get label => switch (this) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.proctor => 'Proctor',
    UserRole.pending => 'Pending',
  };

  /// Returns the default route for the role.
  String get homeLocation => switch (this) {
    UserRole.superAdmin => '/admin',
    UserRole.proctor => '/proctor',
    UserRole.pending => '/pending',
  };

  /// Firestore string representation.
  String get firestoreValue => switch (this) {
    UserRole.superAdmin => 'super_admin',
    UserRole.proctor => 'proctor',
    UserRole.pending => 'pending',
  };

  /// Parses a Firestore role string back to [UserRole].
  static UserRole fromString(String value) => switch (value) {
    'super_admin' => UserRole.superAdmin,
    'proctor' => UserRole.proctor,
    _ => UserRole.pending,
  };
}
