import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'services/auth_service.dart';
import 'services/crm_services.dart';
import 'services/geocoding_service.dart';
import 'services/password_reset_service.dart';
import 'theme/app_theme.dart';
import 'view_models/forgot_password_view_model.dart';
import 'view_models/login_view_model.dart';
import 'view_models/session_view_model.dart';
import 'views/root_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const OgeraCrmApp());
}

class OgeraCrmApp extends StatelessWidget {
  const OgeraCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // One HTTP client for the whole app: it owns the bearer token and is
        // the single place a 401 is noticed.
        Provider<ApiClient>(create: (_) => ApiClient()),
        Provider<SessionStore>(create: (_) => SecureSessionStore()),
        Provider<GeocodingService>(create: (_) => GeocodingService()),

        ProxyProvider2<ApiClient, SessionStore, AuthService>(
          update: (_, api, store, _) => AuthService(api, store),
        ),
        ProxyProvider<ApiClient, ContactsService>(
          update: (_, api, _) => ContactsService(api),
        ),
        ProxyProvider<ApiClient, ProfessionalsService>(
          update: (_, api, _) => ProfessionalsService(api),
        ),
        ProxyProvider<ApiClient, FollowupsService>(
          update: (_, api, _) => FollowupsService(api),
        ),
        ProxyProvider<ApiClient, StaffDirectoryService>(
          update: (_, api, _) => StaffDirectoryService(api),
        ),

        ChangeNotifierProvider<SessionViewModel>(
          create: (context) => SessionViewModel(
            auth: context.read<AuthService>(),
            api: context.read<ApiClient>(),
          )..bootstrap(),
        ),
        ChangeNotifierProvider<LoginViewModel>(
          create: (context) => LoginViewModel(context.read<AuthService>()),
        ),
        Provider<PasswordResetService>(
          create: (context) => PasswordResetService(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<ForgotPasswordViewModel>(
          create: (context) =>
              ForgotPasswordViewModel(context.read<PasswordResetService>()),
        ),
      ],
      child: MaterialApp(
        title: 'Ogera CRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const RootRouter(),
      ),
    );
  }
}
