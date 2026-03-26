import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _firebaseUser;
  UserProfile? _profile;
  bool _loading = false;
  String? _error;

  User? get firebaseUser => _firebaseUser;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isSignedIn => _firebaseUser != null;

  AuthProvider() {
    try {
      _authService.userStream.listen(
        (user) async {
          _firebaseUser = user;
          if (user != null && _profile == null) {
            _profile = await FirestoreService().getProfile(user.uid);
          } else if (user == null) {
            _profile = null;
          }
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Auth stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Firebase not initialized: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _authService.signInWithEmailAndPassword(email, password);
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Firebase not configured. Run: flutterfire configure';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _authService.createUserWithEmailAndPassword(
          email, password, name);
    } on FirebaseAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Firebase not configured. Run: flutterfire configure';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_firebaseUser == null) return;
    final updated = await FirestoreService().getProfile(_firebaseUser!.uid);
    if (updated != null) {
      _profile = updated;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _profile = null;
    notifyListeners();
  }
}
