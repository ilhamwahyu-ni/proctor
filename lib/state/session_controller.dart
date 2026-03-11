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
    _authController.addListener(notifyListeners);
  }

  final SessionRepository _sessionRepository;
  AuthController _authController;

  /// Visible sessions for the current role.
  List<ExamSession> get visibleSessions {
    final role = _authController.currentUser?.role;

    if (role == UserRole.superAdmin) {
      return _sessionRepository.getAllSessions();
    }

    return _sessionRepository.getActiveSessions();
  }

  /// Returns a session by id.
  ExamSession? sessionById(String sessionId) {
    return _sessionRepository.findById(sessionId);
  }

  /// Creates a new scheduled session.
  Future<ExamSession?> createSession({
    required String name,
    required String examUrl,
    required int durationMinutes,
  }) async {
    final currentUser = _authController.currentUser;

    if (currentUser == null || currentUser.role != UserRole.superAdmin) {
      return null;
    }

    final session = _sessionRepository.createSession(
      name: name,
      examUrl: examUrl,
      createdBy: currentUser.id,
      durationMinutes: durationMinutes,
    );

    notifyListeners();
    return session;
  }

  /// Updates the status of a session.
  Future<void> updateStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    _sessionRepository.updateStatus(sessionId: sessionId, status: status);
    notifyListeners();
  }

  /// Reattaches the auth dependency after provider updates.
  void attachAuth(AuthController authController) {
    if (identical(_authController, authController)) {
      return;
    }

    _authController.removeListener(notifyListeners);
    _authController = authController;
    _authController.addListener(notifyListeners);
    notifyListeners();
  }

  @override
  void dispose() {
    _authController.removeListener(notifyListeners);
    super.dispose();
  }
}
