import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:proctor/data/models/exam_session.dart';

/// Session repository backed by Cloud Firestore.
class SessionRepository {
  /// Creates the repository with the Firestore sessions collection.
  SessionRepository()
    : _sessionsRef = FirebaseFirestore.instance.collection('sessions');

  final CollectionReference<Map<String, dynamic>> _sessionsRef;

  /// Watches all sessions sorted by start time.
  Stream<List<ExamSession>> watchAllSessions() {
    return _sessionsRef.orderBy('startsAt').snapshots().map((snapshot) {
      final list = <ExamSession>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(ExamSession.fromFirestore(doc));
        } catch (e, st) {
          debugPrint('Error parsing session ${doc.id}: $e\n$st');
        }
      }
      return list;
    });
  }

  /// Watches only active sessions for proctor views.
  Stream<List<ExamSession>> watchActiveSessions() {
    return _sessionsRef
        .where('status', isEqualTo: 'active')
        .orderBy('startsAt')
        .snapshots()
        .map((snapshot) {
      final list = <ExamSession>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(ExamSession.fromFirestore(doc));
        } catch (e, st) {
          debugPrint('Error parsing session ${doc.id}: $e\n$st');
        }
      }
      return list;
    });
  }

  /// Returns a session by id if available.
  Future<ExamSession?> findById(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return ExamSession.fromFirestore(doc);
  }

  /// Creates a new scheduled session with generated secrets.
  Future<ExamSession> createSession({
    required String name,
    required String examUrl,
    required String createdBy,
    required int durationMinutes,
    required DateTime startsAt,
  }) async {
    final now = DateTime.now();
    final session = ExamSession(
      id: '',
      name: name.trim(),
      examUrl: examUrl.trim(),
      exitSecret: _generateSecret(),
      alarmSecret: _generateSecret(),
      createdBy: createdBy,
      createdAt: now,
      startsAt: startsAt,
      endsAt: startsAt.add(Duration(minutes: durationMinutes)),
      status: SessionStatus.scheduled,
    );

    final docRef = await _sessionsRef.add(session.toMap());
    return session.copyWith(id: docRef.id);
  }

  /// Updates the status of an existing session.
  Future<ExamSession> updateStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    await _sessionsRef.doc(sessionId).update({'status': status.firestoreValue});

    final doc = await _sessionsRef.doc(sessionId).get();
    return ExamSession.fromFirestore(doc);
  }

  /// Updates an existing session's details.
  Future<ExamSession> updateSession({
    required String sessionId,
    required String name,
    required String examUrl,
    required int durationMinutes,
    required DateTime startsAt,
  }) async {
    final docRef = _sessionsRef.doc(sessionId);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Session not found');
    }
    
    final endsAt = startsAt.add(Duration(minutes: durationMinutes));
    
    await docRef.update({
      'name': name.trim(),
      'examUrl': examUrl.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
    });

    final updatedDoc = await docRef.get();
    return ExamSession.fromFirestore(updatedDoc);
  }

  /// Deletes a session.
  Future<void> deleteSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).delete();
  }

  String _generateSecret() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();

    return List.generate(
      16,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
