// STUB — replace this file by running: flutterfire configure
// This lets the app compile and show the UI before a Firebase project is set up.
// Auth and Firestore features will not work until you configure a real project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBOb1VMsMy7MXpi1Spjofcw4aj2AGkU9j8',
    appId: '1:688738048762:web:d5bedb689fda1b39b8c743',
    messagingSenderId: '688738048762',
    projectId: 'reelmind-app-d00f0',
    authDomain: 'reelmind-app-d00f0.firebaseapp.com',
    databaseURL: 'https://reelmind-app-d00f0-default-rtdb.firebaseio.com',
    storageBucket: 'reelmind-app-d00f0.firebasestorage.app',
    measurementId: 'G-QFYQ0D9C8P',
  );

  // ── Placeholder values — replace via: flutterfire configure ──────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMzM95ZMi3OtdMp2Iyn-FAAW-sgW2qxvo',
    appId: '1:688738048762:android:00ee5fdd2d44bad8b8c743',
    messagingSenderId: '688738048762',
    projectId: 'reelmind-app-d00f0',
    databaseURL: 'https://reelmind-app-d00f0-default-rtdb.firebaseio.com',
    storageBucket: 'reelmind-app-d00f0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3HerVAT_MNu5PdLkHzqUs9cy4Fpm4dGw',
    appId: '1:688738048762:ios:acaf570bbb258828b8c743',
    messagingSenderId: '688738048762',
    projectId: 'reelmind-app-d00f0',
    databaseURL: 'https://reelmind-app-d00f0-default-rtdb.firebaseio.com',
    storageBucket: 'reelmind-app-d00f0.firebasestorage.app',
    androidClientId: '688738048762-qotja5c3du0b2q3gfns4jtgalajolnjk.apps.googleusercontent.com',
    iosClientId: '688738048762-bsoajktedcgscs3oafnhgq0cl5lhno4u.apps.googleusercontent.com',
    iosBundleId: 'com.example.videoIdeaApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3HerVAT_MNu5PdLkHzqUs9cy4Fpm4dGw',
    appId: '1:688738048762:ios:acaf570bbb258828b8c743',
    messagingSenderId: '688738048762',
    projectId: 'reelmind-app-d00f0',
    databaseURL: 'https://reelmind-app-d00f0-default-rtdb.firebaseio.com',
    storageBucket: 'reelmind-app-d00f0.firebasestorage.app',
    androidClientId: '688738048762-qotja5c3du0b2q3gfns4jtgalajolnjk.apps.googleusercontent.com',
    iosClientId: '688738048762-bsoajktedcgscs3oafnhgq0cl5lhno4u.apps.googleusercontent.com',
    iosBundleId: 'com.example.videoIdeaApp',
  );

}