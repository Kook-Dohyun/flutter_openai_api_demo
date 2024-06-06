import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class APIinsertPage extends StatefulWidget {
  const APIinsertPage({super.key});

  @override
  State<APIinsertPage> createState() => _APIinsertPageState();
}

class _APIinsertPageState extends State<APIinsertPage> {
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    suffixIcon: (_apiKeyController.text.length < 10)
                        ? null
                        : IconButton(
                            onPressed: () async {
                              await _login(
                                  settingsController: settingsController);
                            },
                            icon: const FaIcon(FontAwesomeIcons.add),
                          ),
                    isDense: true,
                    labelText: labelText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) async {
                    await _login(settingsController: settingsController);
                  },
                  // autofocus: true,
                ),
                Container(
                  margin: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width / 3,
                      vertical: 30),
                  child: ElevatedButton(
                    onPressed: () async {
                      settingsController.googleSignOut();
                    },
                    child: const FaIcon(FontAwesomeIcons.google),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<dynamic> _login(
      {required SettingsController settingsController}) async {
    String insertedAPIKey = _apiKeyController.text;
    bool result = await settingsController.updateApiKey(insertedAPIKey);
    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API Key is valid $insertedAPIKey'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, insertedAPIKey);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid API Key $insertedAPIKey'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, insertedAPIKey);
      }
    }
  }
}
