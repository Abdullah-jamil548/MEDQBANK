import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_strings.dart';
import '../core/network/api_client.dart';
import '../core/network/realtime_client.dart';
import '../core/storage/book_cache.dart';
import '../core/theme/app_theme.dart';
import '../data/datasources/auth_remote.dart';
import '../data/repositories/books_repository_impl.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../data/repositories/college_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/friends_repository_impl.dart';
import '../domain/repositories/books_repository.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/repositories/college_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/friends_repository.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_list_page.dart';
import '../features/chat/presentation/pages/chat_thread_page.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/friends/presentation/pages/friends_page.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
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
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final session = context.read<SessionProvider>();
            return RealtimeClient(getToken: () => session.accessToken);
          },
        ),
        ProxyProvider<SessionProvider, ApiClient>(
          update: (_, session, previous) {
            return ApiClient(
              getToken: () => session.accessToken,
              onUnauthorized: () async {
                if (session.isLoggedIn) {
                  await session.signOut();
                }
              },
            );
          },
        ),
        ProxyProvider<ApiClient, AuthRemote>(
          update: (_, api, __) => AuthRemote(api),
        ),
        ProxyProvider<ApiClient, BooksRepository>(
          update: (_, api, __) => BooksRepositoryImpl(api),
        ),
        ProxyProvider<ApiClient, FriendsRepository>(
          update: (_, api, __) => FriendsRepositoryImpl(api),
        ),
        ProxyProvider<ApiClient, ChatRepository>(
          update: (_, api, __) => ChatRepositoryImpl(api),
        ),
        Provider<BookCache>(create: (_) => BookCache()),
        Provider<CollegeRepository>(create: (_) => CollegeRepositoryImpl()),
        Provider<DashboardRepository>(create: (_) => DashboardRepositoryImpl()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => MainNavProvider()),
        ChangeNotifierProxyProvider2<SessionProvider, AuthRemote, AuthProvider>(
          create: (context) => AuthProvider(
            context.read<SessionProvider>(),
            context.read<AuthRemote>(),
          ),
          update: (_, session, authRemote, previous) =>
              previous ?? AuthProvider(session, authRemote),
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
        ChangeNotifierProxyProvider3<BooksRepository, ApiClient, BookCache, LibraryProvider>(
          create: (context) => LibraryProvider(
            context.read<BooksRepository>(),
            context.read<ApiClient>(),
            context.read<BookCache>(),
          ),
          update: (_, books, api, cache, previous) =>
              previous ?? LibraryProvider(books, api, cache),
        ),
        ChangeNotifierProxyProvider2<FriendsRepository, SessionProvider, FriendsProvider>(
          create: (context) => FriendsProvider(
            context.read<FriendsRepository>(),
            context.read<SessionProvider>(),
          ),
          update: (_, repo, session, previous) {
            final provider = previous ?? FriendsProvider(repo, session);
            if (session.isLoggedIn) {
              provider.startPresence();
            } else {
              provider.stopPresence();
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider3<ChatRepository, SessionProvider, RealtimeClient, ChatProvider>(
          create: (context) => ChatProvider(
            context.read<ChatRepository>(),
            context.read<SessionProvider>(),
            context.read<RealtimeClient>(),
          ),
          update: (_, repo, session, realtime, previous) {
            final provider = previous ?? ChatProvider(repo, session, realtime);
            if (session.isLoggedIn) {
              realtime.start();
            } else {
              realtime.stop();
            }
            return provider;
          },
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
          AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
          AppRoutes.profileSetup: (_) => const ProfileSetupPage(),
          AppRoutes.notifications: (_) => const NotificationPermissionPage(),
          AppRoutes.welcome: (_) => const WelcomePage(),
          AppRoutes.home: (_) => const MainShell(),
          AppRoutes.bookReader: (_) => const BookReaderPage(),
          AppRoutes.friends: (_) => const FriendsPage(),
          AppRoutes.chats: (_) => const ChatListPage(),
          AppRoutes.chatThread: (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
            return ChatThreadPage(
              friendUserId: map['friendUserId']?.toString() ?? '',
              friendName: map['friendName']?.toString() ?? 'Friend',
            );
          },
        },
      ),
    );
  }
}
