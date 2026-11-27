// File generated for the PromptIndo Firebase project (`prompindo`).
//
// Values below come from the Firebase Android app config handed over with the
// brief. Do not commit a real production apiKey rotation without regenerating
// this file (`flutterfire configure`).
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
    apiKey: 'AIzaSyC0ONxrttUUqrjbveJA6NygSuaZECa-63Q',
    appId: '1:66910648137:android:97f0dd1bc066a48bb18c98',
    messagingSenderId: '66910648137',
    projectId: 'prompindo',
    storageBucket: 'prompindo.firebasestorage.app',
  );

  /// iOS app must be registered in the Firebase console before it works —
  /// the bundle id `com.promptindo.ai` matches the Android applicationId so
  /// the same SHA/cert setup can be reused. See README "iOS".
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC0ONxrttUUqrjbveJA6NygSuaZECa-63Q',
    appId: '1:66910648137:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '66910648137',
    projectId: 'prompindo',
    storageBucket: 'prompindo.firebasestorage.app',
    iosBundleId: 'com.promptindo.ai',
  );
}
