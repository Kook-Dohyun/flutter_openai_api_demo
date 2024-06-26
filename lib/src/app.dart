import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openai/src/feature/pages/api_add_page.dart'; 
import 'package:provider/provider.dart';
import 'feature/pages/home_page.dart';
import 'feature/pages/login_page.dart';
import 'settings/settings_controller.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settingsController, child) {
        return MaterialApp(
          restorationScopeId: 'app',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
            Locale('ko', 'KR')
          ],
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          theme: ThemeData(
              useMaterial3: true,
              colorScheme: settingsController.colorSchemeLitght),
          darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: settingsController.colorSchemeDark,
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(backgroundColor: Colors.black)),
          themeMode: settingsController.themeMode,
          home: (settingsController.isLoggedIn)
                  ?(settingsController.apiKey != null)
              ? const HomePage():const APIinsertPage()
              : const LogInPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
