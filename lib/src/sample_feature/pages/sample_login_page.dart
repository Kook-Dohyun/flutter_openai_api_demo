import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class SampleLogInPage extends StatefulWidget {
  const SampleLogInPage({super.key});

  @override
  State<SampleLogInPage> createState() => _SampleLogInPageState();
}

class _SampleLogInPageState extends State<SampleLogInPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  late String labelText = 'Enter your API Key';
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
        builder: (context, settingsController, child) {
      if (settingsController.apiKey != null) {
        _apiKeyController.text = settingsController.apiKey!;
        labelText = 'Your Current Key';
      }
      return Scaffold(
        appBar: AppBar(title: const Text('API Key Login')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: labelText,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              Container(
                margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 3,
                    vertical: 30),
                child: ElevatedButton(
                  onPressed: () async {
                    await _login(settingsController: settingsController);
                  },
                  child: const FaIcon(FontAwesomeIcons.google),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<dynamic> _login(
      {required SettingsController settingsController}) async {
    String sampleApi = _apiKeyController.text;
    bool result = await settingsController.updateApiKey(sampleApi);
    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API Key is valid $sampleApi'),
            backgroundColor: Colors.green,
          ),
        );
        await settingsController.googleSignIn();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid API Key $sampleApi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
