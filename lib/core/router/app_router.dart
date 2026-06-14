import 'package:go_router/go_router.dart';

import '../../state/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/account_blocked_screen.dart';
import '../../features/auth/screens/register_user_screen.dart';
import '../../features/auth/screens/register_porter_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
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
      final isBlockedRoute = loc == '/account-blocked';
      final isResetPasswordRoute = loc == '/reset-password';

      if (isResetPasswordRoute) return null;

      if (auth.blockedAccountMessage != null) {
        return isBlockedRoute ? null : '/account-blocked';
      }

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
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/account-blocked',
        builder: (context, state) => const AccountBlockedScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RolePickerScreen(),
      ),
      GoRoute(
        path: '/choose-role',
        builder: (context, state) =>
            const RolePickerScreen(isGoogleCompletion: true),
      ),
      GoRoute(
        path: '/register/user',
        builder: (context, state) => const RegisterUserScreen(),
      ),
      GoRoute(
        path: '/register/porter',
        builder: (context, state) => const RegisterPorterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/user/home',
        builder: (context, state) => const UserHomeScreen(),
      ),
      GoRoute(
        path: '/porter/home',
        builder: (context, state) => const PorterHomeScreen(),
      ),
      GoRoute(
        path: '/porter/verification',
        builder: (context, state) => const PorterVerificationScreen(),
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
    ],
  );
}
