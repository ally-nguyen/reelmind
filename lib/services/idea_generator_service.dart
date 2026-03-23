import 'package:cloud_functions/cloud_functions.dart';
import '../models/video_idea.dart';
import '../models/user_profile.dart';

class IdeaGeneratorService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the `generateIdea` Cloud Function.
  /// Returns a [VideoIdea] pre-populated with AI title + bullets.
  Future<VideoIdea> generateIdea(UserProfile profile) async {
    final callable = _functions.httpsCallable('generateIdea');

    final result = await callable.call({
      'userId': profile.uid,
      'tasteProfile': profile.tasteProfile.toMap(),
    });

    final data = result.data as Map<String, dynamic>;

    return VideoIdea(
      id: '',
      userId: profile.uid,
      title: data['title'] as String,
      bullets: List<String>.from(data['bullets']),
      source: IdeaSource.aiGenerated,
      status: IdeaStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
