import 'package:flutter/material.dart';
import 'package:openai/src/feature/seperate_pages/assistant_modify_page.dart';
import 'package:openai/src/services/openai_client.dart';
import 'package:provider/provider.dart';
import '../../services/assistant_response_classes.dart';
import '../../settings/settings_controller.dart';
import '../pages/home_page.dart';

class AssistantDetailsPage extends StatelessWidget {
  final Assistant assistant;

  const AssistantDetailsPage({super.key, required this.assistant});

  @override
  Widget build(BuildContext context) {
    final String description = assistant.description ?? '설명없음';
    final String title =
        assistant.name == '' ? '이름없음' : assistant.name ?? '이름없음';
    return Scaffold(
      appBar: AppBar(
        title: Text('$title Info'),
        actions: [
          IconButton(
            tooltip: '수정하기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return ModifyOrCreateAssistantPage(
                      action: '수정',
                      assistant: assistant,
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          Consumer<SettingsController>(
              builder: (context, settingsController, child) {
            final openai = settingsController.openAiClient;
            return IconButton(
              tooltip: '삭제하기',
              onPressed: () {
                showDelDialog(context, openai: openai);
              },
              icon: const Icon(Icons.delete_forever),
            );
          })
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('ID'),
            subtitle: SelectableText(assistant.id),
          ),
          ListTile(
            title: const Text('설명'),
            subtitle: SelectableText(description),
          ),
          ListTile(
            title: const Text('지시사항'),
            subtitle: SelectableText(assistant.instructions.toString()),
          ),
          ListTile(
            title: const Text('생성일'),
            subtitle: Text(
                DateTime.fromMillisecondsSinceEpoch(assistant.createdAt * 1000)
                    .toString()),
          ),
          ListTile(
            title: const Text('모델'),
            subtitle: Text(assistant.model),
          ),
          ...assistant.tools.map((tool) => ListTile(
                title: Text('도구 타입: ${tool.type}'),
                subtitle: tool is FunctionTool
                    ? Text(
                        '기능: ${tool.function.name}, 설명: ${tool.function.description}')
                    : const Text('이 도구에는 추가 세부사항이 없습니다.'),
              )),
        ],
      ),
    );
  }

  void showDelDialog(context, {required OpenAiClient openai}) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('어시스턴트를 영구삭제합니다.'),
          content: const Text(
            '삭제된 후엔 작업을 되돌릴 수 없습니다.\n정말 영구삭제 하시겠습니까?',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('확인'),
              onPressed: () {
                openai.deleteAssistant(assistant.id);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(),
                  ),
                  (Route<dynamic> route) => false, // 모든 경로를 제거
                );
              },
            ),
          ],
        );
      },
    );
  }
}
