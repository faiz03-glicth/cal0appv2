import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-BorAnblavC_4dLvzWKBuCujivrLMnUo',
    appId: '1:674529694062:web:a9e6bddc81c9a55b10b17f',
    messagingSenderId: '674529694062',
    projectId: 'c0application',
    authDomain: 'c0application.firebaseapp.com',
    storageBucket: 'Yc0application.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZcm8VaJMztEVbz4uY9wudjonZdfdnM9U',
    appId: '1:674529694062:web:a9e6bddc81c9a55b10b17f',
    messagingSenderId: '674529694062',
    projectId: 'c0application',
    storageBucket: 'c0application.firebasestorage.app',
  );
}
