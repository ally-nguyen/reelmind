class TasteProfile {
  final List<String> hashtags;
  final List<String> topics;
  final DateTime? lastSynced;

  TasteProfile({
    this.hashtags = const [],
    this.topics = const [],
    this.lastSynced,
  });

  factory TasteProfile.fromMap(Map<String, dynamic> data) {
    return TasteProfile(
      hashtags: List<String>.from(data['hashtags'] ?? []),
      topics: List<String>.from(data['topics'] ?? []),
      lastSynced: data['lastSynced'] != null
          ? (data['lastSynced'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hashtags': hashtags,
      'topics': topics,
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
