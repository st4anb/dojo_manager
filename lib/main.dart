import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'package:app_links/app_links.dart'; // Reativado para Fase 3
import 'package:cloud_firestore/cloud_firestore.dart'; // Reativado para Fase 3

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // HARD RESET: Desativando persistência para limpar queries fantasma de 'users'
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('Firebase OK');
  } catch (e) {
    debugPrint('🚨 ERRO FIREBASE: $e');
  }

  try {
    await initializeDateFormatting('pt_BR', null);
    
    // Reativando Notificações (Suspeito #1)
    await NotificationService.instance.init(); 
    
    debugPrint('Serviços OK');
  } catch (e) {
    debugPrint('🚨 ERRO SERVIÇOS: $e');
  }

  runApp(
    const ProviderScope(
      child: DojoManagerApp(),
    ),
  );
}

class DojoManagerApp extends ConsumerStatefulWidget {
  const DojoManagerApp({super.key});

  @override
  ConsumerState<DojoManagerApp> createState() => _DojoManagerAppState();
}

class _DojoManagerAppState extends ConsumerState<DojoManagerApp> {
  late AppLinks _appLinks; // Reativado suspeito #2

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    try {
      _appLinks = AppLinks();
      _appLinks.uriLinkStream.listen((uri) {
        debugPrint('Deep Link Capturado: $uri');
      });
    } catch (e) {
      debugPrint('🚨 ERRO DEEP LINKS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DOJO V16 - FORCE SYNC',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
