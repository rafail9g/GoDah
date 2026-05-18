import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_user_screen.dart';
import '../../features/auth/screens/register_porter_screen.dart';
import '../../features/auth/screens/role_picker_screen.dart';
import '../../features/user/screens/user_home_screen.dart';
import '../../features/porter/screens/porter_home_screen.dart';
import '../../features/porter/screens/porter_verification_screen.dart';
import '../../features/admin/screens/admin_login_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';

abstract class AppRouter {
  static GoRouter router(AuthProvider auth) => GoRouter(
        initialLocation: '/splash',
        refreshListenable: auth,
        redirect: (context, state) {
          final loc = state.matchedLocation;

          // Halaman publik yang tidak perlu redirect
          final isPublic = loc == '/splash' ||
              loc == '/login' ||
              loc == '/register' ||
              loc == '/register/user' ||
              loc == '/register/porter' ||
              loc == '/admin/login';

          if (auth.isLoading) return '/splash';

          if (!auth.isLoggedIn && !isPublic) return '/login';

          if (auth.isLoggedIn) {
            // Sudah login, jangan ke halaman auth
            if (loc == '/login' ||
                loc == '/register' ||
                loc == '/register/user' ||
                loc == '/register/porter' ||
                loc == '/splash') {
              return auth.role == 'porter' ? '/porter/home' : '/user/home';
            }
          }

          if (auth.isAdminLoggedIn) {
            if (loc == '/admin/login') return '/admin/home';
          }

          return null;
        },
        routes: [
          GoRoute(
            path: '/splash',
            builder: (_, __) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const LoginScreen(),
          ),
          GoRoute(
            path: '/register',
            builder: (_, __) => const RolePickerScreen(),
          ),
          GoRoute(
            path: '/register/user',
            builder: (_, __) => const RegisterUserScreen(),
          ),
          GoRoute(
            path: '/register/porter',
            builder: (_, __) => const RegisterPorterScreen(),
          ),
          GoRoute(
            path: '/user/home',
            builder: (_, __) => const UserHomeScreen(),
          ),
          GoRoute(
            path: '/porter/home',
            builder: (_, __) => const PorterHomeScreen(),
          ),
          GoRoute(
            path: '/porter/verification',
            builder: (_, __) => const PorterVerificationScreen(),
          ),
          GoRoute(
            path: '/admin/login',
            builder: (_, __) => const AdminLoginScreen(),
          ),
          GoRoute(
            path: '/admin/home',
            builder: (_, __) => const AdminHomeScreen(),
          ),
        ],
      );
}
