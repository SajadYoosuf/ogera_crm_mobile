import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'services/auth_service.dart';
import 'services/crm_services.dart';
import 'services/geocoding_service.dart';
import 'services/location_api_service.dart';
import 'services/location_queue.dart';
import 'services/location_tracking_service.dart';
import 'theme/app_theme.dart';
import 'view_models/login_view_model.dart';
import 'view_models/session_view_model.dart';
import 'views/root_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        Provider<LocationQueue>(create: (_) => LocationQueue()),

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
        ProxyProvider<ApiClient, SalesService>(
          update: (_, api, _) => SalesService(api),
        ),
        ProxyProvider<ApiClient, StaffDirectoryService>(
          update: (_, api, _) => StaffDirectoryService(api),
        ),
        ProxyProvider<ApiClient, LocationApiService>(
          update: (_, api, _) => LocationApiService(api),
        ),
        ProxyProvider2<
          LocationApiService,
          LocationQueue,
          LocationTrackingService
        >(
          update: (_, api, queue, previous) =>
              previous ?? LocationTrackingService(api, queue),
          dispose: (_, service) => service.dispose(),
        ),

        ChangeNotifierProvider<SessionViewModel>(
          create: (context) => SessionViewModel(
            auth: context.read<AuthService>(),
            api: context.read<ApiClient>(),
            tracking: context.read<LocationTrackingService>(),
          )..bootstrap(),
        ),
        ChangeNotifierProvider<LoginViewModel>(
          create: (context) => LoginViewModel(context.read<AuthService>()),
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
