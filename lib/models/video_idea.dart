enum IdeaStatus { draft, scripted, filmed, posted }

enum IdeaSource { manual, aiGenerated }

class VideoIdea {
  final String id;
  final String userId;
  String title;
  List<String> bullets;
  IdeaStatus status;
  IdeaSource source;
  final DateTime createdAt;
  DateTime updatedAt;

  VideoIdea({
    required this.id,
    required this.userId,
    required this.title,
    required this.bullets,
    this.status = IdeaStatus.draft,
    this.source = IdeaSource.manual,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VideoIdea.fromFirestore(Map<String, dynamic> data, String id) {
    return VideoIdea(
      id: id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      bullets: List<String>.from(data['bullets'] ?? []),
      status: IdeaStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => IdeaStatus.draft,
      ),
      source: IdeaSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => IdeaSource.manual,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'bullets': bullets,
      'status': status.name,
      'source': source.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
