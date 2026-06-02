import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'state/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  await Supabase.initialize(
    url: 'https://eohytcqfugefhjydhtrp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvaHl0Y3FmdWdlZmhqeWRodHJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMTI4MDQsImV4cCI6MjA5NDU4ODgwNH0.l6uozOQW8jk_8WTB9ytv87oGDjLNwqrbISUsPQ33Oz8',
  );

  runApp(const GoDahApp());
}

class GoDahApp extends StatelessWidget {
  const GoDahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp.router(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: AppRouter.router(auth),
          );
        },
      ),
    );
  }
}