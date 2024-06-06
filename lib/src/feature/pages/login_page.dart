import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class LogInPage extends StatefulWidget {
  const LogInPage({super.key});

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
        builder: (context, settingsController, child) {
      return Scaffold(
          body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _login(settingsController: settingsController);
          },
          child: const FaIcon(FontAwesomeIcons.google),
        ),
      ));
    });
  }

  Future<dynamic> _login(
      {required SettingsController settingsController}) async {
    bool result = await settingsController.googleSignIn();
    if (mounted) {
      String? user = settingsController.currentUser?.displayName ??
          settingsController.currentUser?.email;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text((result) ? 'Well Come Back! $user' : 'Well Come! $user'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
