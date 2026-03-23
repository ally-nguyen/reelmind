import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_idea.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/idea_generator_service.dart';

class IdeasProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final IdeaGeneratorService _generatorService = IdeaGeneratorService();

  List<VideoIdea> _ideas = [];
  bool _generating = false;
  String? _error;
  StreamSubscription<List<VideoIdea>>? _subscription;

  List<VideoIdea> get ideas => _ideas;
  bool get generating => _generating;
  String? get error => _error;

  List<VideoIdea> byStatus(IdeaStatus status) =>
      _ideas.where((i) => i.status == status).toList();

  void listenToIdeas(String uid) {
    _subscription?.cancel();
    _subscription = _firestoreService.ideasStream(uid).listen((ideas) {
      _ideas = ideas;
      notifyListeners();
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _ideas = [];
    notifyListeners();
  }

  Future<VideoIdea> createManualIdea(String uid, String title) async {
    final idea = VideoIdea(
      id: '',
      userId: uid,
      title: title,
      bullets: [],
      source: IdeaSource.manual,
      status: IdeaStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _firestoreService.createIdea(idea);
  }

  Future<VideoIdea?> generateAiIdea(UserProfile profile) async {
    _generating = true;
    _error = null;
    notifyListeners();
    try {
      final idea = await _generatorService.generateIdea(profile);
      return await _firestoreService.createIdea(idea);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  Future<void> saveIdea(VideoIdea idea) => _firestoreService.updateIdea(idea);

  Future<void> updateStatus(String uid, String ideaId, IdeaStatus status) =>
      _firestoreService.updateIdeaStatus(uid, ideaId, status);

  Future<void> deleteIdea(String uid, String ideaId) =>
      _firestoreService.deleteIdea(uid, ideaId);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
