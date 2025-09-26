// lib/main.dart - VERSÃO SEM FIREBASE COM JWT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REMOVIDO: Imports Firebase
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'package:firebase_auth/firebase_auth.dart';

import 'services/api_service.dart';
import 'widgets/auth_wrapper.dart';

// Import Providers
import 'providers/auth_provider.dart' as AppAuthProvider;
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'providers/accounting_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/voice_provider.dart'; // <<< CORREÇÃO: Importado

// Import Utils
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REMOVIDO: Firebase initialization
  // try {
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  //   Logger.info('Firebase Initialization Successful.');
  // } catch (e, stackTrace) {
  //   Logger.error('Firebase Initialization Failed', error: e, stackTrace: stackTrace);
  // }

  // JWT System Initialization
  try {
    Logger.info('Initializing JWT Authentication System...');

    // Verificar se há token salvo (para debug)
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwt_token');

    if (savedToken != null) {
      Logger.info('JWT Token found in local storage');
    } else {
      Logger.info('No JWT Token found - user will need to login');
    }

    Logger.info('JWT Authentication System initialized successfully.');
  } catch (e, stackTrace) {
    Logger.error('JWT System initialization failed', error: e, stackTrace: stackTrace);
  }

  // Orientação de tela (apenas se não for web)
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      Logger.info('Screen orientation set to portrait.');
    } catch (e, stackTrace) {
      Logger.error('Failed to set screen orientation', error: e, stackTrace: stackTrace);
    }
  } else {
    Logger.info('Running on web - skipping orientation lock.');
  }

  Logger.info('Running Vitrine Borracharia App with JWT Authentication.');
  runApp(const VitrineBorrachariaApp());
}

class VitrineBorrachariaApp extends StatelessWidget {
  const VitrineBorrachariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    Logger.debug('Building VitrineBorrachariaApp Widget with JWT providers.');

    return MultiProvider(
      providers: [
        // REMOVIDO: Firebase Auth Provider
        // Provider<FirebaseAuth>(
        //   create: (_) => FirebaseAuth.instance,
        // ),

        // Nível 1: ApiService - ATUALIZADO para não precisar de Firebase
        Provider<ApiService>(
          create: (context) {
            Logger.info('main.dart: Criando ApiService sem Firebase');
            return ApiService(); // Construtor sem Firebase
          },
        ),

        // Nível 2: AuthProvider - ATUALIZADO para JWT
        ChangeNotifierProxyProvider<ApiService, AppAuthProvider.AuthProvider>(
          create: (context) {
            Logger.info('main.dart: Criando AuthProvider para JWT');
            return AppAuthProvider.AuthProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info('main.dart: Atualizando AuthProvider');
            // Reutilizar instância anterior se possível
            if (previous != null) {
              return previous;
            }
            return AppAuthProvider.AuthProvider(apiService);
          },
        ),

        // Nível 3: ProductProvider - SEM MUDANÇAS
        ChangeNotifierProxyProvider<ApiService, ProductProvider>(
          create: (context) {
            Logger.info('main.dart: Criando ProductProvider');
            return ProductProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info('main.dart: Atualizando ProductProvider');
            if (previous != null) {
              return previous;
            }
            return ProductProvider(apiService);
          },
        ),

        // Nível 4: CartProvider - SEM MUDANÇAS
        ChangeNotifierProxyProvider<ApiService, CartProvider>(
          create: (context) {
            Logger.info('main.dart: Criando CartProvider');
            return CartProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info('main.dart: Atualizando CartProvider');
            if (previous != null) {
              return previous;
            }
            return CartProvider(apiService);
          },
        ),

        // Nível 5: OrderProvider - SEM MUDANÇAS
        ChangeNotifierProxyProvider2<ApiService, ProductProvider, OrderProvider>(
          create: (context) {
            Logger.info('main.dart: Criando OrderProvider');
            return OrderProvider(
              context.read<ApiService>(),
              context.read<ProductProvider>(),
            );
          },
          update: (_, apiService, productProvider, previous) {
            Logger.info('main.dart: Atualizando OrderProvider');
            if (previous != null) {
              return previous;
            }
            return OrderProvider(apiService, productProvider);
          },
        ),

        // Nível 6: UserProvider - SEM MUDANÇAS
        ChangeNotifierProxyProvider<ApiService, UserProvider>(
          create: (context) {
            Logger.info("main.dart: Criando UserProvider");
            return UserProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info("main.dart: Atualizando UserProvider");
            if (previous != null) {
              return previous;
            }
            return UserProvider(apiService);
          },
        ),

        // Nível 7: AccountingProvider - CORREÇÃO APLICADA
        ChangeNotifierProxyProvider<ApiService, AccountingProvider>(
          create: (context) {
            Logger.info("main.dart: Criando AccountingProvider");
            return AccountingProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info("main.dart: Atualizando AccountingProvider");
            if (previous != null) {
              return previous;
            }
            // CORREÇÃO: Passar ApiService completo, não submódulo
            return AccountingProvider(apiService);
          },
        ),

        // Nível 8: TransactionProvider - CORREÇÃO APLICADA
        ChangeNotifierProxyProvider<ApiService, TransactionProvider>(
          create: (context) {
            Logger.info("main.dart: Criando TransactionProvider");
            return TransactionProvider(context.read<ApiService>());
          },
          update: (_, apiService, previous) {
            Logger.info("main.dart: Atualizando TransactionProvider");
            if (previous != null) {
              return previous;
            }
            // CORREÇÃO: Passar ApiService completo, não submódulo
            return TransactionProvider(apiService);
          },
        ),

        // <<< CORREÇÃO: VoiceProvider adicionado à árvore de widgets >>>
        ChangeNotifierProvider(
          create: (context) {
            Logger.info("main.dart: Criando VoiceProvider");
            return VoiceProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Vitrine Borracharia',
        debugShowCheckedModeBanner: false,

        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E1E2C),
          primaryColor: const Color(0xFF9147FF),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF9147FF),
            secondary: const Color(0xFF7289DA),
            background: const Color(0xFF2C2F33),
            surface: const Color(0xFF23272A),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Colors.white70,
            onSurface: Colors.white,
            onError: Colors.redAccent,
          ),
          cardColor: const Color(0xFF2C2F33),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF23272A),
            elevation: 0,
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gothic',
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF23272A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Color(0xFF4F545C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Color(0xFF9147FF), width: 2),
            ),
            labelStyle: TextStyle(color: Colors.white70),
            hintStyle: TextStyle(color: Colors.white54),
            prefixIconColor: Colors.white70,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Gothic', fontSize: 14),
            titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Gothic'),
            labelLarge: TextStyle(color: Color(0xFF9147FF), fontWeight: FontWeight.bold, fontFamily: 'Gothic'),
            headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Gothic'),
            titleMedium: TextStyle(color: Colors.white70, fontFamily: 'Gothic'),
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Gothic'),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7289DA),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF23272A),
            selectedItemColor: Color(0xFF9147FF),
            unselectedItemColor: Colors.white54,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: TextStyle(fontSize: 12),
          ),
        ),

        home: const AuthWrapper(),
      ),
    );
  }
}
