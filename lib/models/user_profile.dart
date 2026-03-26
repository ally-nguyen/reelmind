class TasteProfile {
  // Combined signals used for generation (video-first priority)
  final List<String> hashtags;
  final List<String> topics;

  // Their own posts — all media types
  final List<String> ownHashtags;
  final List<String> ownTopics;

  // Their own video posts specifically (Reels etc.)
  final List<String> videoHashtags;
  final List<String> videoTopics;

  // Content they've liked (requires user_liked_media permission)
  final List<String> likedHashtags;
  final List<String> likedTopics;

  final int videoCount;
  final int totalPostsAnalyzed;
  final DateTime? lastSynced;

  TasteProfile({
    this.hashtags = const [],
    this.topics = const [],
    this.ownHashtags = const [],
    this.ownTopics = const [],
    this.videoHashtags = const [],
    this.videoTopics = const [],
    this.likedHashtags = const [],
    this.likedTopics = const [],
    this.videoCount = 0,
    this.totalPostsAnalyzed = 0,
    this.lastSynced,
  });

  factory TasteProfile.fromMap(Map<String, dynamic> data) {
    return TasteProfile(
      hashtags: List<String>.from(data['hashtags'] ?? []),
      topics: List<String>.from(data['topics'] ?? []),
      ownHashtags: List<String>.from(data['ownHashtags'] ?? []),
      ownTopics: List<String>.from(data['ownTopics'] ?? []),
      videoHashtags: List<String>.from(data['videoHashtags'] ?? []),
      videoTopics: List<String>.from(data['videoTopics'] ?? []),
      likedHashtags: List<String>.from(data['likedHashtags'] ?? []),
      likedTopics: List<String>.from(data['likedTopics'] ?? []),
      videoCount: data['videoCount'] as int? ?? 0,
      totalPostsAnalyzed: data['totalPostsAnalyzed'] as int? ?? 0,
      lastSynced: data['lastSynced'] != null
          ? (data['lastSynced'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hashtags': hashtags,
      'topics': topics,
      'ownHashtags': ownHashtags,
      'ownTopics': ownTopics,
      'videoHashtags': videoHashtags,
      'videoTopics': videoTopics,
      'likedHashtags': likedHashtags,
      'likedTopics': likedTopics,
      'videoCount': videoCount,
      'totalPostsAnalyzed': totalPostsAnalyzed,
      'lastSynced': lastSynced,
    };
  }
}

class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;
  final bool instagramConnected;
  final TasteProfile tasteProfile;

  UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.instagramConnected = false,
    TasteProfile? tasteProfile,
  }) : tasteProfile = tasteProfile ?? TasteProfile();

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      instagramConnected: data['instagramConnected'] as bool? ?? false,
      tasteProfile: data['tasteProfile'] != null
          ? TasteProfile.fromMap(data['tasteProfile'])
          : TasteProfile(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'instagramConnected': instagramConnected,
      'tasteProfile': tasteProfile.toMap(),
    };
  }
}
