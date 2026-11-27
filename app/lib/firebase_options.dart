// File generated for the PromptIndo Firebase project (`donghuamax-6e38d`).
//
// The Android app (`promptindo.app`) is registered in this project. Keep this
// file in sync with `android/app/google-services.json`.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'PromptIndo ships mobile only.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC6qaPDeOQobTYRfvUmSwn8o6rNfLY3ow0',
    appId: '1:132450727224:android:1758c4a2a656bd6accfdcd',
    messagingSenderId: '132450727224',
    projectId: 'donghuamax-6e38d',
    storageBucket: 'donghuamax-6e38d.firebasestorage.app',
  );

  /// iOS app must be registered in the Firebase console before it works —
  /// the bundle id `com.promptindo.ai` matches the Android applicationId so
  /// the same SHA/cert setup can be reused. See README "iOS".
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC6qaPDeOQobTYRfvUmSwn8o6rNfLY3ow0',
    appId: '1:132450727224:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '132450727224',
    projectId: 'donghuamax-6e38d',
    storageBucket: 'donghuamax-6e38d.firebasestorage.app',
    iosBundleId: 'com.promptindo.promptindo',
  );
}
