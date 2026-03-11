import 'package:proctor/data/models/app_user.dart';
import 'package:proctor/data/models/user_role.dart';

/// In-memory auth repository used to scaffold Proctor flows before Firebase.
class AuthRepository {
  /// Creates the repository with seeded users.
  AuthRepository() : _users = _seedUsers();

  final List<AppUser> _users;
  final Map<String, String> _passwords = {
    'admin@proctor.local': 'admin123',
    'proctor@proctor.local': 'proctor123',
    'pending@proctor.local': 'pending123',
  };

  static List<AppUser> _seedUsers() {
    final now = DateTime.now();

    return [
      AppUser(
        id: 'u-super-admin',
        email: 'admin@proctor.local',
        displayName: 'Koordinator Ujian',
        role: UserRole.superAdmin,
        createdAt: now.subtract(const Duration(days: 14)),
        isActive: true,
      ),
      AppUser(
        id: 'u-proctor-1',
        email: 'proctor@proctor.local',
        displayName: 'Pengawas Ruang A',
        role: UserRole.proctor,
        createdAt: now.subtract(const Duration(days: 7)),
        isActive: true,
      ),
      AppUser(
        id: 'u-pending-1',
        email: 'pending@proctor.local',
        displayName: 'Calon Pengawas',
        role: UserRole.pending,
        createdAt: now.subtract(const Duration(days: 1)),
        isActive: false,
      ),
    ];
  }

  /// Returns all known users sorted by creation time.
  List<AppUser> getUsers() {
    final users = [..._users]
      ..sort((left, right) {
        return right.createdAt.compareTo(left.createdAt);
      });

    return users;
  }

  /// Attempts to sign in a user with email and password.
  AppUser? signIn({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();
    final storedPassword = _passwords[normalizedEmail];

    if (storedPassword != password) {
      return null;
    }

    return _users.where((user) => user.email == normalizedEmail).firstOrNull;
  }

  /// Registers a new pending user.
  AppUser register({
    required String email,
    required String displayName,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final id = 'u-${_users.length + 1}';

    final user = AppUser(
      id: id,
      email: normalizedEmail,
      displayName: displayName.trim(),
      role: UserRole.pending,
      createdAt: DateTime.now(),
      isActive: false,
    );

    _users.add(user);
    _passwords[normalizedEmail] = password;

    return user;
  }

  /// Creates a new active proctor account directly from super admin flow.
  AppUser createManagedProctor({
    required String email,
    required String displayName,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    final id = 'u-${_users.length + 1}';

    final user = AppUser(
      id: id,
      email: normalizedEmail,
      displayName: displayName.trim(),
      role: UserRole.proctor,
      createdAt: DateTime.now(),
      isActive: true,
    );

    _users.add(user);
    _passwords[normalizedEmail] = password;

    return user;
  }

  /// Updates a user's role and active flag.
  AppUser updateUser({required String userId, UserRole? role, bool? isActive}) {
    final index = _users.indexWhere((user) => user.id == userId);
    final updatedUser = _users[index].copyWith(role: role, isActive: isActive);

    _users[index] = updatedUser;
    return updatedUser;
  }

  /// Returns whether the email is already registered.
  bool emailExists(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    return _users.any((user) => user.email == normalizedEmail);
  }
}
