import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/user_role.dart';
import '../../../core/network/network_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final hasNet = await NetworkService.isConnected();
    if (!hasNet) {
      throw const SocketException('Chưa kết nối mạng! Vui lòng kiểm tra Wi-Fi hoặc 4G/5G.');
    }

    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    final hasNet = await NetworkService.isConnected();
    if (!hasNet) {
      throw const SocketException('Chưa kết nối mạng! Vui lòng kiểm tra Wi-Fi hoặc 4G/5G.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': displayName ?? email.split('@').first,
        'role': role.code,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return credential;
  }

  Stream<UserRole> getUserRoleStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return UserRole.teacher;
      final data = doc.data();
      final roleStr = data?['role'] as String?;
      return UserRole.fromString(roleStr);
    });
  }

  Future<void> updateUserRole({
    required String targetUid,
    required UserRole newRole,
  }) async {
    await _firestore.collection('users').doc(targetUid).update({
      'role': newRole.code,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class SocketException implements Exception {
  final String message;
  const SocketException(this.message);

  @override
  String toString() => message;
}
