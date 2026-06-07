import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'state/providers/auth_provider.dart';
import 'core/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://eohytcqfugefhjydhtrp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvaHl0Y3FmdWdlZmhqeWRodHJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMTI4MDQsImV4cCI6MjA5NDU4ODgwNH0.l6uozOQW8jk_8WTB9ytv87oGDjLNwqrbISUsPQ33Oz8',
  );

  await FcmService.instance.init();

  runApp(const GoDahApp());
}

class GoDahApp extends StatefulWidget {
  const GoDahApp({super.key});

  @override
  State<GoDahApp> createState() => _GoDahAppState();
}

class _GoDahAppState extends State<GoDahApp> {
  late final AuthProvider _auth;
  late final _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider()..init();
    _router = AppRouter.router(_auth);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: _AppLifecycleSync(
        auth: _auth,
        child: MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}

class _AppLifecycleSync extends StatefulWidget {
  final AuthProvider auth;
  final Widget child;

  const _AppLifecycleSync({
    required this.auth,
    required this.child,
  });

  @override
  State<_AppLifecycleSync> createState() => _AppLifecycleSyncState();
}

class _AppLifecycleSyncState extends State<_AppLifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.auth.refreshCurrentSession();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
