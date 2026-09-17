import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../data/datasources/books_api.dart';
import '../data/repositories/college_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/library_repository_impl.dart';
import '../domain/repositories/college_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/library_repository.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/providers/dashboard_provider.dart';
import '../features/library/presentation/pages/book_reader_page.dart';
import '../features/library/presentation/providers/library_provider.dart';
import '../features/notifications/presentation/pages/notification_permission_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../features/profile_setup/presentation/pages/profile_setup_page.dart';
import '../features/profile_setup/presentation/providers/profile_setup_provider.dart';
import '../features/session/presentation/providers/session_provider.dart';
import '../features/shell/presentation/pages/main_shell.dart';
import '../features/shell/presentation/providers/main_nav_provider.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/welcome/presentation/pages/welcome_page.dart';
import 'routes.dart';

class MedQBankApp extends StatelessWidget {
  const MedQBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CollegeRepository>(create: (_) => CollegeRepositoryImpl()),
        Provider<DashboardRepository>(create: (_) => DashboardRepositoryImpl()),
        Provider<LibraryRepository>(create: (_) => LibraryRepositoryImpl(booksApi: BooksApi())),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => MainNavProvider()),
        ChangeNotifierProxyProvider<SessionProvider, AuthProvider>(
          create: (context) => AuthProvider(context.read<SessionProvider>()),
          update: (_, session, previous) => previous ?? AuthProvider(session),
        ),
        ChangeNotifierProxyProvider2<CollegeRepository, SessionProvider, ProfileSetupProvider>(
          create: (context) => ProfileSetupProvider(
            context.read<CollegeRepository>(),
            context.read<SessionProvider>(),
          ),
          update: (_, repository, session, previous) =>
              previous ?? ProfileSetupProvider(repository, session),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(context.read<DashboardRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => LibraryProvider(context.read<LibraryRepository>()),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.15,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashPage(),
          AppRoutes.onboarding: (_) => const OnboardingPage(),
          AppRoutes.login: (_) => const LoginPage(),
          AppRoutes.signup: (_) => const SignupPage(),
          AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
          AppRoutes.profileSetup: (_) => const ProfileSetupPage(),
          AppRoutes.notifications: (_) => const NotificationPermissionPage(),
          AppRoutes.welcome: (_) => const WelcomePage(),
          AppRoutes.home: (_) => const MainShell(),
          AppRoutes.bookReader: (_) => const BookReaderPage(),
        },
      ),
    );
  }
}
