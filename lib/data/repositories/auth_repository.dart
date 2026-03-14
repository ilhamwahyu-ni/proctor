import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proctor/data/models/app_user.dart';
import 'package:proctor/data/models/user_role.dart';

/// Auth repository backed by Firebase Auth and Firestore.
class AuthRepository {
  /// Creates the repository with Firebase instances.
  AuthRepository()
    : _auth = FirebaseAuth.instance,
      _usersRef = FirebaseFirestore.instance.collection('users');

  final FirebaseAuth _auth;
  final CollectionReference<Map<String, dynamic>> _usersRef;

  /// Returns all known users sorted by creation time (newest first).
  Future<List<AppUser>> getUsers() async {
    final snapshot = await _usersRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  /// Signs in with email/password via Firebase Auth and returns the
  /// corresponding Firestore user profile.
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) return null;

    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Registers a new pending user via Firebase Auth and creates the
  /// matching Firestore profile.
  Future<AppUser> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(
      id: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      role: UserRole.pending,
      createdAt: DateTime.now(),
      isActive: false,
    );

    await _usersRef.doc(uid).set(user.toMap());
    return user;
  }

  /// Creates a new active proctor account directly (super admin flow).
  Future<AppUser> createManagedProctor({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(
      id: uid,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      role: UserRole.proctor,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _usersRef.doc(uid).set(user.toMap());

    // Sign back in as the super admin after creating the proctor.
    // The super admin's credentials are lost after createUser, so we
    // rely on the controller to re-authenticate.
    return user;
  }

  /// Updates a user's role and/or active flag in Firestore.
  Future<AppUser> updateUser({
    required String userId,
    UserRole? role,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (role != null) updates['role'] = role.firestoreValue;
    if (isActive != null) updates['isActive'] = isActive;

    await _usersRef.doc(userId).update(updates);

    final doc = await _usersRef.doc(userId).get();
    return AppUser.fromFirestore(doc);
  }

  /// Returns whether the email is already registered in the system.
  Future<bool> emailExists(String email) async {
    final snapshot = await _usersRef
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Restores the currently signed-in user from Firebase Auth state.
  Future<AppUser?> restoreUser() async {
    final firebaseUser = _auth.currentUser ?? await _auth.authStateChanges().first;
    if (firebaseUser == null) return null;

    try {
      final doc = await _usersRef.doc(firebaseUser.uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Signs the current user out of Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Re-authenticates the super admin after creating a managed proctor.
  Future<void> reAuthenticateSuperAdmin({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }
}
