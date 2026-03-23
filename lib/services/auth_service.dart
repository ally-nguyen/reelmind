import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserProfile?> signInWithEmailAndPassword(
      String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return _fetchOrCreateProfile(cred.user!);
  }

  Future<UserProfile?> createUserWithEmailAndPassword(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(displayName);
    return _fetchOrCreateProfile(cred.user!);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserProfile> _fetchOrCreateProfile(User user) async {
    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();

    if (!snap.exists) {
      final profile = UserProfile(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
      );
      await doc.set(profile.toFirestore());
      return profile;
    }

    return UserProfile.fromFirestore(snap.data()!, user.uid);
  }
}
