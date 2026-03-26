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
      id: data['id'] as String,
      userId: profile.uid,
      title: data['title'] as String,
      bullets: List<String>.from(data['bullets']),
      source: IdeaSource.aiGenerated,
      status: IdeaStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Calls the `generateBullets` Cloud Function.
  /// Takes the user's own [title] and returns AI-generated bullet points
  /// tailored to their Instagram taste profile.
  Future<List<String>> generateBullets(String userId, String title, {String? userInput}) async {
    final callable = _functions.httpsCallable('generateBullets');
    final payload = <String, dynamic>{'userId': userId, 'title': title};
    if (userInput != null && userInput.isNotEmpty) payload['userInput'] = userInput;
    final result = await callable.call(payload);
    final data = result.data as Map<String, dynamic>;
    return List<String>.from(data['bullets']);
  }
}
