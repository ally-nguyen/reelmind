import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// Replace with your Instagram App credentials
const _instagramClientId = 'YOUR_INSTAGRAM_APP_ID';
const _redirectUri = 'reelmind://oauth/instagram'; // register in Info.plist / AndroidManifest

class InstagramService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Launches Instagram OAuth flow and stores the token server-side via
  /// the `connectInstagram` Cloud Function (token never stored on device).
  Future<void> connectInstagram(String uid) async {
    final authUrl = Uri.https('api.instagram.com', '/oauth/authorize', {
      'client_id': _instagramClientId,
      'redirect_uri': _redirectUri,
      'scope': 'user_profile,user_media',
      'response_type': 'code',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'reelmind',
    );

    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw Exception('Instagram OAuth failed: no code');

    // Exchange code server-side — the Cloud Function stores the token in
    // Firestore and updates instagramConnected = true on the user doc.
    final callable = _functions.httpsCallable('connectInstagram');
    await callable.call({'uid': uid, 'code': code});
  }

  /// Triggers a fresh sync of the user's Instagram feed signals.
  Future<void> syncFeed(String uid) async {
    final callable = _functions.httpsCallable('syncInstagramFeed');
    await callable.call({'uid': uid});
  }
}
