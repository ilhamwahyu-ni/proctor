import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:proctor/data/models/exam_session.dart';
import 'package:proctor/data/models/user_role.dart';
import 'package:proctor/data/repositories/session_repository.dart';
import 'package:proctor/state/auth_controller.dart';

/// Shared session state for dashboards and OTP views.
class SessionController extends ChangeNotifier {
  /// Creates the session controller.
  SessionController({
    required SessionRepository sessionRepository,
    required AuthController authController,
  }) : _sessionRepository = sessionRepository,
       _authController = authController {
    _authController.addListener(_onAuthChanged);
    // Load immediately only when auth is already ready (app restart scenario).
    // If not yet ready, _onAuthChanged will trigger loadSessions once
    // initialize() completes.
    if (_authController.isReady && _authController.isAuthenticated) {
      loadSessions();
    }
  }

  final SessionRepository _sessionRepository;
  AuthController _authController;
  StreamSubscription<List<ExamSession>>? _sessionSubscription;

  List<ExamSession> _sessions = [];
  bool _isLoading = false;

  /// Whether sessions are currently being fetched.
  bool get isLoading => _isLoading;

  /// Visible sessions for the current role (from cache).
  List<ExamSession> get visibleSessions => _sessions;

  /// Loads sessions from Firestore based on the current user's role and listens for updates.
  void loadSessions() {
    _sessionSubscription?.cancel();

    final role = _authController.currentUser?.role;
    if (role == null) {
      _sessions = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final stream = role == UserRole.superAdmin
        ? _sessionRepository.watchAllSessions()
        : _sessionRepository.watchActiveSessions();

    _sessionSubscription = stream.listen(
      (sessions) {
        _sessions = sessions;
        _isLoading = false;
        notifyListeners();
      },
      onError: (dynamic e, dynamic st) {
        debugPrint('Error loading sessions stream: $e\n$st');
        _sessions = [];
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Returns a session by id.
  ExamSession? sessionById(String sessionId) {
    return _sessions.where((s) => s.id == sessionId).firstOrNull;
  }

  /// Creates a new scheduled session.
  Future<ExamSession?> createSession({
    required String name,
    required String examUrl,
    required int durationMinutes,
    required DateTime startsAt,
  }) async {
    final currentUser = _authController.currentUser;

    if (currentUser == null || currentUser.role != UserRole.superAdmin) {
      return null;
    }

    try {
      final session = await _sessionRepository.createSession(
        name: name,
        examUrl: examUrl,
        createdBy: currentUser.id,
        durationMinutes: durationMinutes,
        startsAt: startsAt,
      );

      return session;
    } catch (e, st) {
      debugPrint('Error creating session: $e\n$st');
      return null;
    }
  }

  /// Updates the status of a session.
  Future<void> updateStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    await _sessionRepository.updateStatus(sessionId: sessionId, status: status);
  }

  /// Updates an existing session's details.
  Future<ExamSession?> updateSession({
    required String sessionId,
    required String name,
    required String examUrl,
    required int durationMinutes,
    required DateTime startsAt,
  }) async {
    final currentUser = _authController.currentUser;

    if (currentUser == null || currentUser.role != UserRole.superAdmin) {
      return null;
    }

    try {
      final session = await _sessionRepository.updateSession(
        sessionId: sessionId,
        name: name,
        examUrl: examUrl,
        durationMinutes: durationMinutes,
        startsAt: startsAt,
      );
      
      return session;
    } catch (e, st) {
      debugPrint('Error updating session: $e\n$st');
      return null;
    }
  }

  /// Deletes a session.
  Future<void> deleteSession(String sessionId) async {
    final currentUser = _authController.currentUser;
    if (currentUser == null || currentUser.role != UserRole.superAdmin) {
      return;
    }

    try {
      await _sessionRepository.deleteSession(sessionId);
    } catch (e, st) {
      debugPrint('Error deleting session: $e\n$st');
    }
  }

  /// Reattaches the auth dependency after provider updates.
  void attachAuth(AuthController authController) {
    if (identical(_authController, authController)) {
      return;
    }

    _authController.removeListener(_onAuthChanged);
    _authController = authController;
    _authController.addListener(_onAuthChanged);

    // If auth is already ready and user is logged in (e.g. app restart where
    // initialize() finished before ProxyProvider triggered this update),
    // we must manually load sessions because _onAuthChanged won't fire again.
    if (_authController.isReady && _authController.isAuthenticated) {
      Future.microtask(loadSessions);
    } else {
      Future.microtask(notifyListeners);
    }
  }

  void _onAuthChanged() {
    if (_authController.isAuthenticated) {
      loadSessions();
    } else {
      _sessions = [];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
