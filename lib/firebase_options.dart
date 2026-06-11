import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCkolwxNkLKdG0Ptf8vDrkxkq8q4TjRgVE',
    appId: '1:603427447748:web:cf7a616227844b1887fa91',
    messagingSenderId: '603427447748',
    projectId: 'go-dah',
    authDomain: 'go-dah.firebaseapp.com',
    storageBucket: 'go-dah.firebasestorage.app',
    measurementId: 'G-M5GKRLJPHZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB88nYcoTvDR_PYaVfVONALQbnTugDYwas',
    appId: '1:603427447748:android:6bc715517014362c87fa91',
    messagingSenderId: '603427447748',
    projectId: 'go-dah',
    storageBucket: 'go-dah.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAzLqxC1G28lyQDcQxpD1t0bEsjHMEo6wc',
    appId: '1:603427447748:ios:1d61538933b8834887fa91',
    messagingSenderId: '603427447748',
    projectId: 'go-dah',
    storageBucket: 'go-dah.firebasestorage.app',
    iosBundleId: 'com.example.goDah',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAzLqxC1G28lyQDcQxpD1t0bEsjHMEo6wc',
    appId: '1:603427447748:ios:1d61538933b8834887fa91',
    messagingSenderId: '603427447748',
    projectId: 'go-dah',
    storageBucket: 'go-dah.firebasestorage.app',
    iosBundleId: 'com.example.goDah',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCkolwxNkLKdG0Ptf8vDrkxkq8q4TjRgVE',
    appId: '1:603427447748:web:c5c809ce2644e15987fa91',
    messagingSenderId: '603427447748',
    projectId: 'go-dah',
    authDomain: 'go-dah.firebaseapp.com',
    storageBucket: 'go-dah.firebasestorage.app',
    measurementId: 'G-59PTV7VGQ7',
  );
}
