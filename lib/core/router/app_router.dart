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
      if (auth.isLoading) return '/splash';

      final isAuthPage =
          loc == '/login' ||
          loc == '/register' ||
          loc == '/register/user' ||
          loc == '/register/porter';

      // Admin sudah login
      if (auth.isAdminLoggedIn) {
        if (isAuthPage || loc == '/splash') return '/admin/home';
        return null;
      }

      // User/porter sudah login
      if (auth.isLoggedIn) {
        if (isAuthPage || loc == '/splash') {
          return auth.role == 'porter' ? '/porter/home' : '/user/home';
        }
        return null;
      }

      // Belum login — boleh ke halaman auth, redirect sisanya ke login
      if (!isAuthPage && loc != '/splash') return '/login';

      // Dari splash tanpa session → ke login
      if (loc == '/splash') return '/login';

      return null;
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
