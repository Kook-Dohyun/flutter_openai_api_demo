import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:openai/src/settings/settings_controller.dart';

class SettingDrawer extends StatelessWidget {
  const SettingDrawer({super.key, required this.controller});
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Theme(
        data: Theme.of(context).copyWith(
          drawerTheme: DrawerThemeData(
            elevation: 0,
            shape: const RoundedRectangleBorder(),
            endShape: const RoundedRectangleBorder(),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        child: NavigationDrawer(
          indicatorColor: Colors.amber,
          children: [
            ListTile(
              leading: controller.themeMode == ThemeMode.system
                  ? const Icon(Icons.storm_rounded)
                  : controller.themeMode == ThemeMode.dark
                      ? const Icon(Icons.mode_night)
                      : const Icon(Icons.sunny),
              title: const Text('Theme Mode'),
              trailing: DropdownButton<ThemeMode>(
                enableFeedback: true,
                isDense: true,
                underline: const SizedBox(),
                value: controller.themeMode,
                onChanged: controller.updateThemeMode,
                items: const [
                  DropdownMenuItem(
                      value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(
                      value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
            ),
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(15, 8, 8, 8),
                  child: Text('Theme: '),
                ),
                ...controller.colorMap.entries.map((entry) {
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(2), // 아이콘과 테두리 간의 간격 조절
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            controller.seedColor == entry.value // 현재 선택된 색상 확인
                                ? Border.all(
                                    color: Colors.white,
                                    width: 2) // 선택 시 하얀 테두리 적용
                                : null, // 선택되지 않은 색상에는 테두리 없음
                      ),
                      child: Icon(Icons.circle,
                          color: entry.value), // 원형 아이콘과 해당 컬러
                    ),
                    onPressed: () {
                      controller.updateSeedColorKey(entry.key); // 버튼 탭 시 호출
                    },
                  );
                })
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Text('Base URL: '),
              title: Text(
                controller.baseUrl!,
                maxLines: 1,
              ),
              minTileHeight: 10,
              onTap: () {},
            ),
            ListTile(
              leading: const Text('API Version: '),
              title: Text(
                controller.apiVersion!,
                maxLines: 1,
              ),
              minTileHeight: 10,
              onTap: () {},
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Manage API Keys',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (String apiKey in controller.apiKeys) ...[
              ListTile(
                title: Text(
                  apiKey,
                  maxLines: 1,
                ),
                minTileHeight: 10,
                leading: apiKey == controller.apiKey
                    ? const Icon(
                        Icons.vpn_key,
                        size: 20,
                      ).animate().moveX(
                        begin: -20, curve: Curves.easeInOutCubicEmphasized)
                    : const SizedBox(),
                // trailing: IconButton(
                //   icon: const Icon(Icons.delete),
                //   onPressed: () => removeApiKey(context, apiKey),
                // ),
                onTap: () {
                  controller.setCurrentApiKey(apiKey);
                  // Navigator.pop(context);
                },
              ),
            ],
            ListTile(
              title: TextField(
                decoration: const InputDecoration(labelText: 'Add new API Key'),
                onSubmitted: (newKey) => addApiKey(context, newKey),
              ),
              leading: const Icon(Icons.add),
            ),
            ListTile(
              title: const Text('Logout'),
              trailing: const Icon(Icons.logout_outlined),
              onTap: () {
                controller.googleSignOut();
              },
            )
          ],
        ),
      ),
    );
  }

  void removeApiKey(BuildContext context, String apiKey) async {
    Completer<void> completer = Completer<void>();
    controller.removeApiKey(apiKey).then((success) {
      if (!completer.isCompleted && success) {
        completer.complete();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key removed successfully.')));
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        completer.complete();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error removing API key.')));
      }
    });
  }

  void addApiKey(BuildContext context, String newKey) {
    Completer<void> completer = Completer<void>();
    controller.updateApiKey(newKey).then((success) {
      if (!completer.isCompleted && success) {
        completer.complete();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key added successfully.')));
      } else if (!completer.isCompleted) {
        completer.complete();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid API key.')));
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        completer.complete();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error adding API key.')));
      }
    });
  }
}
