import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:proctor/data/models/app_user.dart';
import 'package:proctor/data/models/user_role.dart';
import 'package:proctor/data/repositories/auth_repository.dart';

/// Shared auth state for login, registration, and role management.
class AuthController extends ChangeNotifier {
  /// Creates the auth controller.
  AuthController(this._authRepository);

  final AuthRepository _authRepository;
  final Logger _logger = Logger('AuthController');

  AppUser? _currentUser;
  bool _isReady = false;

  /// Whether startup bootstrap is complete.
  bool get isReady => _isReady;

  /// Currently signed-in user if any.
  AppUser? get currentUser => _currentUser;

  /// Whether a session is active.
  bool get isAuthenticated => _currentUser != null;

  /// All known users.
  List<AppUser> get allUsers => _authRepository.getUsers();

  /// Users still waiting for approval.
  List<AppUser> get pendingUsers {
    return allUsers.where((user) => user.role == UserRole.pending).toList();
  }

  /// Proctor users managed by super admin.
  List<AppUser> get approvedProctors {
    return allUsers.where((user) => user.role == UserRole.proctor).toList();
  }

  /// Active proctor users only.
  List<AppUser> get activeProctors {
    return approvedProctors.where((user) => user.isActive).toList();
  }

  /// Marks the controller ready for routing decisions.
  void initialize() {
    _isReady = true;
    notifyListeners();
  }

  /// Attempts to sign in using the seeded repository data.
  Future<bool> signIn({required String email, required String password}) async {
    final user = _authRepository.signIn(email: email, password: password);

    if (user == null) {
      _logger.warning('Failed sign in for $email');
      return false;
    }

    _currentUser = user;
    notifyListeners();
    return true;
  }

  /// Registers a new pending proctor account.
  Future<bool> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    if (_authRepository.emailExists(email)) {
      return false;
    }

    _currentUser = _authRepository.register(
      email: email,
      displayName: displayName,
      password: password,
    );
    notifyListeners();
    return true;
  }

  /// Creates a proctor account directly from the super admin dashboard.
  Future<bool> createManagedProctor({
    required String email,
    required String displayName,
    required String password,
  }) async {
    if (_authRepository.emailExists(email)) {
      return false;
    }

    _authRepository.createManagedProctor(
      email: email,
      displayName: displayName,
      password: password,
    );
    notifyListeners();
    return true;
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  /// Approves a pending user as an active proctor.
  Future<void> approveProctor(String userId) async {
    final updated = _authRepository.updateUser(
      userId: userId,
      role: UserRole.proctor,
      isActive: true,
    );

    _refreshCurrentUser(updated);
  }

  /// Enables or disables a proctor account.
  Future<void> setProctorActive({
    required String userId,
    required bool isActive,
  }) async {
    final updated = _authRepository.updateUser(
      userId: userId,
      isActive: isActive,
    );

    _refreshCurrentUser(updated);
  }

  void _refreshCurrentUser(AppUser updated) {
    if (_currentUser?.id == updated.id) {
      _currentUser = updated;
    }

    notifyListeners();
  }
}
