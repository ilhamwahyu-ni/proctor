import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // Temporary fix for Web and other platforms to prevent UnsupportedError crash.
        // On web, we fall back to the android config which shares the same projectId.
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBHmvid6PmuGE2mVWN3BpHIJ6jjA8B_KK8',
    appId: '1:47030456256:android:6209fb38b6a3b895788225',
    messagingSenderId: '47030456256',
    projectId: 'exambrodanproktor',
    storageBucket: 'exambrodanproktor.firebasestorage.app',
  );

}