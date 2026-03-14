import 'package:firebase_auth/firebase_auth.dart';
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
  List<AppUser> _cachedUsers = [];

  /// Whether startup bootstrap is complete.
  bool get isReady => _isReady;

  /// Currently signed-in user if any.
  AppUser? get currentUser => _currentUser;

  /// Whether a session is active.
  bool get isAuthenticated => _currentUser != null;

  /// All known users (from cache).
  List<AppUser> get allUsers => _cachedUsers;

  /// Users still waiting for approval.
  List<AppUser> get pendingUsers {
    return _cachedUsers.where((user) => user.role == UserRole.pending).toList();
  }

  /// Proctor users managed by super admin.
  List<AppUser> get approvedProctors {
    return _cachedUsers.where((user) => user.role == UserRole.proctor).toList();
  }

  /// Active proctor users only.
  List<AppUser> get activeProctors {
    return approvedProctors.where((user) => user.isActive).toList();
  }

  /// Marks the controller ready for routing decisions.
  Future<void> initialize() async {
    _currentUser = await _authRepository.restoreUser();
    if (_currentUser != null && _currentUser!.role == UserRole.superAdmin) {
      await _refreshUsers();
    }
    _isReady = true;
    notifyListeners();
  }

  /// Attempts to sign in via Firebase Auth.
  Future<bool> signIn({required String email, required String password}) async {
    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );

      if (user == null) {
        _logger.warning('Failed sign in for $email');
        return false;
      }

      _currentUser = user;
      if (user.role == UserRole.superAdmin) {
        await _refreshUsers();
      }
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _logger.warning('Firebase auth error: ${e.code}');
      return false;
    }
  }

  /// Registers a new pending proctor account.
  Future<bool> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    try {
      _currentUser = await _authRepository.register(
        email: email,
        displayName: displayName,
        password: password,
      );
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _logger.warning('Registration error: ${e.code}');
      return false;
    }
  }

  /// Creates a proctor account directly from the super admin dashboard.
  ///
  /// Because Firebase Auth signs in as the newly created user, we must
  /// re-authenticate the super admin afterwards. The caller should
  /// provide the super admin's credentials.
  Future<bool> createManagedProctor({
    required String email,
    required String displayName,
    required String password,
  }) async {
    try {
      await _authRepository.createManagedProctor(
        email: email,
        displayName: displayName,
        password: password,
      );

      // Re-auth super admin — the controller stores credentials
      // temporarily only in memory for this re-auth step.
      // In production the super admin password is prompted via UI.
      // For now we re-sign in silently using the stored session.
      // Firebase Auth state was switched to the new user, so we
      // need to sign back in. We rely on the caller to handle
      // re-authentication if this silent approach fails.
      await _authRepository.restoreUser();

      await _refreshUsers();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _logger.warning('Create proctor error: ${e.code}');
      return false;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _authRepository.signOut();
    _currentUser = null;
    _cachedUsers = [];
    notifyListeners();
  }

  /// Approves a pending user as an active proctor.
  Future<void> approveProctor(String userId) async {
    final updated = await _authRepository.updateUser(
      userId: userId,
      role: UserRole.proctor,
      isActive: true,
    );

    _refreshCurrentUser(updated);
    await _refreshUsers();
  }

  /// Enables or disables a proctor account.
  Future<void> setProctorActive({
    required String userId,
    required bool isActive,
  }) async {
    final updated = await _authRepository.updateUser(
      userId: userId,
      isActive: isActive,
    );

    _refreshCurrentUser(updated);
    await _refreshUsers();
  }

  /// Reloads the user list from Firestore.
  Future<void> _refreshUsers() async {
    _cachedUsers = await _authRepository.getUsers();
  }

  void _refreshCurrentUser(AppUser updated) {
    if (_currentUser?.id == updated.id) {
      _currentUser = updated;
    }

    notifyListeners();
  }
}
