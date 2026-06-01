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
import '../../features/admin/screens/admin_home_screen.dart';

abstract class AppRouter {
  static GoRouter router(AuthProvider auth) => GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Masih loading session — tetap di splash
      if (auth.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final isAuthRoute =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/register/user' ||
          loc == '/register/porter';

      final isSplash = loc == '/splash';

      // ── Admin sudah login ──────────────────────────────────────
      if (auth.isAdminLoggedIn) {
        if (isAuthRoute || isSplash) return '/admin/home';
        return null;
      }

      // ── User/porter sudah login ────────────────────────────────
      if (auth.isLoggedIn) {
        // Kalau masih di halaman auth atau splash, arahkan ke home
        if (isAuthRoute || isSplash) {
          return auth.role == 'porter' ? '/porter/home' : '/user/home';
        }
        // Sudah di halaman yang benar, biarkan
        return null;
      }

      // ── Belum login ────────────────────────────────────────────
      // Boleh akses halaman auth
      if (isAuthRoute) return null;

      // Dari splash tanpa session → ke login
      if (isSplash) return '/login';

      // Halaman lain tanpa login → redirect ke login
      return '/login';
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RolePickerScreen()),
      GoRoute(
        path: '/register/user',
        builder: (_, __) => const RegisterUserScreen(),
      ),
      GoRoute(
        path: '/register/porter',
        builder: (_, __) => const RegisterPorterScreen(),
      ),
      GoRoute(path: '/user/home', builder: (_, __) => const UserHomeScreen()),
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
