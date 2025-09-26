// lib/firebase_options.dart
// Arquivo gerado para o projeto "ecomerce-apks"

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // As credenciais Web são diferentes, mas podemos usar as do Android como base
      // se você não tiver um app Web configurado no Firebase.
      // Para um build web funcional, o ideal é adicionar um app Web no seu projeto Firebase.
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Configuração para Web (gerada a partir dos dados do Android)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgGuVWSx4NULLMr1zf4LYia1qcKD7ww28Y',
    appId: '1:753481854109:web:SUA_WEB_APP_ID_SE_TIVER', // Você precisaria do ID do app Web do Firebase
    messagingSenderId: '753481854109',
    projectId: 'ecomerce-apks',
    authDomain: 'ecomerce-apks.firebaseapp.com',
    storageBucket: 'ecomerce-apks.appspot.com',
  );

  // Configuração para Android (extraída do seu google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgGuVWSx4NULLMr1zf4LYia1qcKD7ww28Y',
    appId: '1:753481854109:android:5932b5037a7e7b2327f874',
    messagingSenderId: '753481854109',
    projectId: 'ecomerce-apks',
    storageBucket: 'ecomerce-apks.appspot.com',
  );
}
