import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:openai/src/services/assistant_response_classes.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

import '../widgets/setting_drawer_widget.dart';
import '../child_pages/assistant_modify_page.dart';
import '../child_pages/assistant_detail_page.dart';
import 'image_page.dart';
import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamController<List<Assistant>> _streamController;
  late AnimationController _refreshIconAnimeController;
  late Timer? _timer;
  late List<Assistant> _localAssistants = [];
  late DateTime updateTime;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    updateTime = DateTime.now();
    _refreshIconAnimeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _streamController = StreamController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLoadingAssistants();
    });
  }

  Future<void> _startLoadingAssistants() async {
    await _loadFirestoreAssistants();
    await _loadAssistants();
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      await _loadAssistants();
    });
  }

  Future<void> _loadAssistants() async {
    final firestore = FirebaseFirestore.instance;
    final settingsController = context.read<SettingsController>();
    final openai = settingsController.openAiClient;
    final user = settingsController.currentUser!;
    final apiKey = settingsController.apiKey!;

    final List<Assistant> apiAssistants = await openai.listAssistants();

    for (final assistant in apiAssistants) {
      final docRef = firestore
          .collection(user.uid)
          .doc(apiKey)
          .collection('Assistants')
          .doc(assistant.id);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists || docSnapshot.data()! != assistant.toJson()) {
        await docRef.set(assistant.toJson());
      }
    }
    _streamController.add(apiAssistants);
    setState(() {
      updateTime = DateTime.now();
    });
  }

  void _manualRefreshAssistants() async {
    _refreshIconAnimeController.repeat();
    _timer?.cancel();
    await _startLoadingAssistants();
    if (mounted) {
      _refreshIconAnimeController.stop();
    }
  }

  Future<void> _loadFirestoreAssistants() async {
    final firestore = FirebaseFirestore.instance;
    final settingsController = context.read<SettingsController>();
    final user = settingsController.currentUser!;
    final apiKey = settingsController.apiKey!;

    List<Assistant> firestoreAssistants = [];

    var querySnapshot = await firestore
        .collection(user.uid)
        .doc(apiKey)
        .collection('Assistants')
        .get();

    for (var doc in querySnapshot.docs) {
      firestoreAssistants.add(Assistant.fromJson(doc.data()));
    }

    _localAssistants = firestoreAssistants;
  }

  Future<void> deleteAssistant(String assistantId) async {
    final firestore = FirebaseFirestore.instance;
    final settingsController = context.read<SettingsController>();
    final user = settingsController.currentUser!;
    final apiKey = settingsController.apiKey!;
    try {
      await firestore
          .collection(user.uid)
          .doc(apiKey)
          .collection('Assistants')
          .doc(assistantId)
          .delete();
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('deleted assistant'),
        ));
      });
    }
  }

  bool widgetBinded = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('OpenAI API'),
        actions: [
          IconButton(
              tooltip: '새로고침',
              onPressed: _manualRefreshAssistants,
              icon: const Icon(Icons.refresh_rounded)
                  .animate(
                    controller: _refreshIconAnimeController,
                  )
                  .rotate(curve: Curves.easeInCubic, duration: 1000.ms)),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: Consumer<SettingsController>(
        builder: (context, settingsController, child) {
          return SettingDrawer(controller: settingsController);
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Assistant>>(
              stream: _streamController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        widgetBinded = mounted;
                      });
                    }
                  });
                  if (widgetBinded) {
                    return Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ListView(
                        children: [
                          ExpansionTile(
                            visualDensity: const VisualDensity(vertical: 0),
                            title: const Text('Assistants'),
                            maintainState: true,
                            enableFeedback: true,
                            trailing: _isExpanded
                                ? IconButton(
                                    tooltip: '어시스턴트 추가',
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ModifyOrCreateAssistantPage(
                                                  action: '추가'),
                                        ),
                                      );

                                      _manualRefreshAssistants();
                                    },
                                    icon:
                                        const Icon(Icons.add)) // 펼친 상태일 때의 아이콘
                                : const Icon(
                                    Icons.arrow_drop_down), // 펼치지 않은 상태일 때의 아이콘
                            onExpansionChanged: (bool expanded) {
                              setState(() {
                                _isExpanded = expanded; // 펼침 상태 업데이트
                              });
                            },
                            children: [
                              if (snapshot.data!.isEmpty)
                                ListTile(
                                  title:
                                      const Text('어시스턴트가 없습니다. 어시스턴트를 생성하세요'),
                                  trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ModifyOrCreateAssistantPage(
                                                action: '추가'),
                                      ),
                                    );

                                    _manualRefreshAssistants();
                                  },
                                ),
                              if (snapshot.data!.isNotEmpty)
                                ...snapshot.data!
                                    .asMap()
                                    .entries
                                    .map<ListTile>((entry) {
                                  int index = entry.key + 1;
                                  Assistant assistant = entry.value;
                                  return ListTile(
                                    leading: Text('$index '), // Index 표현
                                    title: Text(assistant.name ?? '이름 없음'),
                                    subtitle: Text(
                                        (assistant.description == null ||
                                                assistant.description == '')
                                            ? '설명 없음'
                                            : assistant.description!),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ChatPage(assistant: assistant),
                                        ),
                                      );

                                      _manualRefreshAssistants();
                                    },
                                    onLongPress: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                TextButton(
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text('디테일 뷰로 이동'),
                                                      Icon(Icons
                                                          .arrow_forward_ios_rounded),
                                                    ],
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(
                                                        context); // 첫 번째 다이얼로그 닫기
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            AssistantDetailsPage(
                                                                assistant:
                                                                    assistant),
                                                      ),
                                                    );

                                                    _manualRefreshAssistants();
                                                  },
                                                ),
                                                const Divider(),
                                                TextButton(
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text('삭제하기'),
                                                      Icon(Icons.delete),
                                                    ],
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(
                                                        context); // 첫 번째 다이얼로그 닫기
                                                    await showDeleteDialog(
                                                        context,
                                                        assistant,
                                                        false); // 삭제 확인 다이얼로그 띄우기

                                                    _manualRefreshAssistants();
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                }),
                              ..._localAssistants
                                  .where((local) => !snapshot.data!
                                      .map((a) => a.id)
                                      .contains(local.id))
                                  .map((assistant) {
                                TextStyle textStyle =
                                    const TextStyle(color: Colors.grey);
                                return ListTile(
                                  leading: Text(
                                    '${snapshot.data!.length + 1} ',
                                    style: textStyle,
                                  ),
                                  title: Text(
                                    assistant.name ?? '이름 없음',
                                    style: textStyle,
                                  ),
                                  subtitle: Text(
                                    assistant.description ?? '설명 없음',
                                    style: textStyle,
                                  ),
                                  onTap: () {
                                    showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Consumer<SettingsController>(
                                              builder: (context,
                                                  settingsController, child) {
                                            final openai =
                                                settingsController.openAiClient;
                                            return AlertDialog(
                                              title: Text(assistant.name ?? ''),
                                              content: const Text('살리기'),
                                              actions: [
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    textStyle: Theme.of(context)
                                                        .textTheme
                                                        .labelLarge,
                                                  ),
                                                  child: const Text('취소'),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    textStyle: Theme.of(context)
                                                        .textTheme
                                                        .labelLarge,
                                                  ),
                                                  child: const Text('확인'),
                                                  onPressed: () async {
                                                    bool isSuccess = await openai
                                                        .createAssistant(
                                                            name:
                                                                assistant.name,
                                                            description:
                                                                assistant
                                                                    .description,
                                                            model:
                                                                assistant.model,
                                                            instructions:
                                                                assistant
                                                                    .instructions,
                                                            topP:
                                                                assistant.topP,
                                                            temperature:
                                                                assistant
                                                                    .temperature,
                                                            tools: assistant
                                                                .tools);
                                                    if (isSuccess) {
                                                      deleteAssistant(
                                                          assistant.id);
                                                      _manualRefreshAssistants();
                                                    }
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback(
                                                            (timeStamp) {
                                                      Navigator.pop(
                                                          context); // 삭제 다이얼로그 닫기
                                                    });
                                                  },
                                                ),
                                              ],
                                            );
                                          });
                                        });
                                  },
                                  onLongPress: () async {
                                    await showDeleteDialog(
                                        context, assistant, true);
                                    _manualRefreshAssistants();
                                  },
                                );
                              })
                            ],
                          ),
                          const Divider(
                            endIndent: 20,
                            indent: 20,
                          ),
                          ListTile(
                            title: const Text('Images'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios_rounded),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ImagePage()),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }
                  return Container();
                } else if (snapshot.hasError) {
                  return Text('오류가 발생했습니다: ${snapshot.error}');
                }
                return const Text("데이터가 없습니다.");
              },
            ),
          ),
          Text(
            '업데이트: ${updateTime.toString()}',
            style: TextStyle(
                color: Theme.of(context).textTheme.labelSmall!.color,
                fontSize: 11),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamController.close();
    super.dispose();
  }

  Future<void> showDeleteDialog(
      BuildContext context, Assistant assistant, bool deletePermanent) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Consumer<SettingsController>(
            builder: (context, settingsController, child) {
          final openai = settingsController.openAiClient;
          return AlertDialog(
            title: Text(deletePermanent ? '어시스턴트 영구삭제' : '어시스턴트 삭제'),
            content: Text(deletePermanent
                ? '작업을 되돌릴 수 없습니다.\n정말 영구삭제 하시겠습니까?'
                : 'OpenAI 서버에서 삭제합니다.'),
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
                  deletePermanent
                      ? deleteAssistant(assistant.id)
                      : openai.deleteAssistant(assistant.id);
                  _manualRefreshAssistants();
                  Navigator.pop(context); // 삭제 다이얼로그 닫기
                },
              ),
            ],
          );
        });
      },
    );
  }
}
