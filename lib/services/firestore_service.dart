import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_idea.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User Profile ──────────────────────────────────────────────────────────

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromFirestore(snap.data()!, uid);
  }

  Future<void> updateProfile(UserProfile profile) {
    return _db
        .collection('users')
        .doc(profile.uid)
        .update(profile.toFirestore());
  }

  // ── Ideas ─────────────────────────────────────────────────────────────────

  /// Real-time stream of all ideas for a user, sorted by most recently updated.
  Stream<List<VideoIdea>> ideasStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('ideas')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VideoIdea.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<VideoIdea> createIdea(VideoIdea idea) async {
    final ref = await _db
        .collection('users')
        .doc(idea.userId)
        .collection('ideas')
        .add(idea.toFirestore());
    return VideoIdea.fromFirestore(idea.toFirestore(), ref.id);
  }

  Future<void> updateIdea(VideoIdea idea) {
    idea.updatedAt = DateTime.now();
    return _db
        .collection('users')
        .doc(idea.userId)
        .collection('ideas')
        .doc(idea.id)
        .update(idea.toFirestore());
  }

  Future<void> deleteIdea(String uid, String ideaId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('ideas')
        .doc(ideaId)
        .delete();
  }

  Future<void> updateIdeaStatus(
      String uid, String ideaId, IdeaStatus status) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('ideas')
        .doc(ideaId)
        .update({'status': status.name, 'updatedAt': DateTime.now()});
  }
}
