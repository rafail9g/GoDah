import 'package:go_router/go_router.dart';

import '../../state/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_user_screen.dart';
import '../../features/auth/screens/register_porter_screen.dart';
import '../../features/auth/screens/role_picker_screen.dart';
import '../../features/user/screens/user_home_screen.dart';
import '../../features/user/screens/user_tracking_screen.dart';
import '../../features/porter/screens/porter_home_screen.dart';
import '../../features/porter/screens/porter_verification_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';

abstract class AppRouter {
  static GoRouter router(AuthProvider auth) => GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (auth.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final isAuthRoute =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/register/user' ||
          loc == '/register/porter';

      final isSplash = loc == '/splash';
      final isChooseRole = loc == '/choose-role';

      if (auth.needsRoleSelection) {
        return isChooseRole ? null : '/choose-role';
      }

      if (auth.isAdminLoggedIn) {
        if (isAuthRoute || isSplash || isChooseRole) {
          return '/admin/home';
        }
        return null;
      }

      if (auth.isLoggedIn) {
        if (isAuthRoute || isSplash || isChooseRole) {
          return auth.role == 'porter' ? '/porter/home' : '/user/home';
        }
        return null;
      }

      if (isAuthRoute) return null;
      if (isSplash) return '/login';
      return '/login';
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RolePickerScreen()),
      GoRoute(
        path: '/choose-role',
        builder: (_, __) => const RolePickerScreen(isGoogleCompletion: true),
      ),
      GoRoute(
        path: '/register/user',
        builder: (_, __) => const RegisterUserScreen(),
      ),
      GoRoute(
        path: '/register/porter',
        builder: (_, __) => const RegisterPorterScreen(),
      ),
      GoRoute(path: '/user/home', builder: (_, __) => const UserHomeScreen()),

      // ── ROUTE TRACKING — dipanggil dari user_history_tab ──
      GoRoute(
        path: '/user/tracking',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return UserTrackingScreen(
            orderId:      extra['orderId']      as String,
            porterId:     extra['porterId']     as String,
            latJemput:    extra['latJemput']    as double,
            lngJemput:    extra['lngJemput']    as double,
            latTujuan:    extra['latTujuan']    as double,
            lngTujuan:    extra['lngTujuan']    as double,
            lokasiJemput: extra['lokasiJemput'] as String,
            lokasiTujuan: extra['lokasiTujuan'] as String,
          );
        },
      ),

      GoRoute(
        path: '/porter/home',
        builder: (_, __) => const PorterHomeScreen(),
      ),
      GoRoute(
        path: '/porter/verification',
        builder: (_, __) => const PorterVerificationScreen(),
      ),
      GoRoute(path: '/admin/home', builder: (_, __) => const AdminHomeScreen()),
    ],
  );
}