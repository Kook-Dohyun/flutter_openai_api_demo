import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:openai/src/services/assistant_response_classes.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  late List<Assistant> _localAssistants = [];
  late AnimationController _refreshIconAnimeController;
  late Timer? _timer;
  late DateTime updateTime;

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
    await _loadAssistantsFromFirestore();
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

  Future<void> _loadAssistantsFromFirestore() async {
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
    setState(() {
      _localAssistants = firestoreAssistants;
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
          content: Text('error'),
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
              tooltip: AppLocalizations.of(context)!.refresh,
              onPressed: _manualRefreshAssistants,
              icon: const Icon(Icons.refresh_rounded)
                  .animate(
                    controller: _refreshIconAnimeController,
                  )
                  .rotate(curve: Curves.easeInCubic, duration: 1000.ms)),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings),
            onPressed: () async {
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
                    return HomepageBody(
                        manualRefreshAssistants: _manualRefreshAssistants,
                        showDeleteDialog: showDeleteDialog,
                        deleteAssistant: deleteAssistant,
                        snapshot: snapshot,
                        localAssistants: _localAssistants);
                  }
                  return Container();
                } else if (snapshot.hasError) {
                  return Text(
                      '${AppLocalizations.of(context)!.errorAccured}: ${snapshot.error}');
                }
                return Text(AppLocalizations.of(context)!.noData);
              },
            ),
          ),
          Text(
            '${AppLocalizations.of(context)!.update}: ${updateTime.toString()}',
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
            title: Text(deletePermanent
                ? AppLocalizations.of(context)!
                    .homepage_assistantDelete_permenant
                : AppLocalizations.of(context)!.homepage_assistantDelete),
            content: Text(deletePermanent
                ? AppLocalizations.of(context)!
                    .homepage_assistantDelete_permenant_checkout
                : AppLocalizations.of(context)!
                    .homepage_assistantDelete_checkout),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(AppLocalizations.of(context)!.cancel),
                onPressed: () async {
                  Navigator.pop(context);
                  _manualRefreshAssistants();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(AppLocalizations.of(context)!.confirm),
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

class HomepageBody extends StatefulWidget {
  final Function manualRefreshAssistants;
  final Function showDeleteDialog;
  final Function deleteAssistant;
  final AsyncSnapshot<List<Assistant>> snapshot;
  final List<Assistant> localAssistants;

  const HomepageBody({
    super.key,
    required this.manualRefreshAssistants,
    required this.showDeleteDialog,
    required this.deleteAssistant,
    required this.snapshot,
    required this.localAssistants,
  });

  @override
  State<HomepageBody> createState() => _HomepageBodyState();
}

class _HomepageBodyState extends State<HomepageBody> {
  late final _manualRefreshAssistants = widget.manualRefreshAssistants;
  late final _showDeleteDialog = widget.showDeleteDialog;
  late final _deleteAssistant = widget.deleteAssistant;
  late final List<Assistant> _dbAssistants =
      widget.snapshot.data?.toList() ?? [];
  late final List<Assistant> _localAssistants = widget.localAssistants;
  bool _isExpanded = false;
  final _imagePageTitle = 'Dall-E';
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenHeight = constraints.maxHeight;

      final expansionTileHeight = (screenHeight) / 2.5;

      return Column(
        children: [
          Card(
            color: Theme.of(context).colorScheme.onPrimary,
            clipBehavior: Clip.hardEdge,
            margin: const EdgeInsets.all(10),
            elevation: 8,
            child: ListTile(
              leading: const Icon(Icons.brush),
              title: Text(_imagePageTitle),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ImagePage(title: _imagePageTitle)),
                );
              },
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              visualDensity: const VisualDensity(vertical: 0),
              title: const Text('Assistants'),
              maintainState: true,
              enableFeedback: true,
              initiallyExpanded: true,
              trailing: _isExpanded
                  ? IconButton(
                      tooltip:
                          AppLocalizations.of(context)!.homepage_addAssistant,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ModifyOrCreateAssistantPage(
                                action: AppLocalizations.of(context)!.add),
                          ),
                        );

                        _manualRefreshAssistants();
                      },
                      icon: const Icon(Icons.add),
                    ) // 펼친 상태일 때의 아이콘
                  : const Icon(
                      Icons.arrow_drop_down_sharp), // 펼치지 않은 상태일 때의 아이콘
              onExpansionChanged: (bool expanded) {
                setState(() {
                  _isExpanded = expanded; // 펼침 상태 업데이트
                });
              },
              children: [
                if (_dbAssistants.isEmpty)
                  ListTile(
                    title: Text(
                        AppLocalizations.of(context)!.homepage_noAssistant),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ModifyOrCreateAssistantPage(
                              action: AppLocalizations.of(context)!.add),
                        ),
                      );

                      _manualRefreshAssistants();
                    },
                  )
                else if (_dbAssistants.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: expansionTileHeight,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ..._dbAssistants
                              .asMap()
                              .entries
                              .map<ListTile>((entry) {
                            int index = entry.key + 1;
                            Assistant assistant = entry.value;
                            return ListTile(
                              leading: Text('$index '), // Index 표현
                              title: Hero(
                                  tag: assistant.id,
                                  child: Material(
                                      type: MaterialType.transparency,
                                      child: Text(assistant.name ??
                                          AppLocalizations.of(context)!
                                              .homepage_noName))),
                              subtitle: Text((assistant.description == null ||
                                      assistant.description == '')
                                  ? AppLocalizations.of(context)!
                                      .homepage_noDescription
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
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(AppLocalizations.of(
                                                        context)!
                                                    .homepage_goToDetailView),
                                                const Icon(Icons
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
                                                          assistant: assistant),
                                                ),
                                              );

                                              _manualRefreshAssistants();
                                            },
                                          ),
                                          const Divider(),
                                          TextButton(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(AppLocalizations.of(
                                                        context)!
                                                    .delete),
                                                const Icon(Icons.delete),
                                              ],
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await _showDeleteDialog(
                                                  context, assistant, false);
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
                        ],
                      ),
                    ),
                  ),
                if (_localAssistants.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: expansionTileHeight,
                    ),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        ..._localAssistants
                            .where((local) => !_dbAssistants
                                .map((a) => a.id)
                                .contains(local.id))
                            .map((assistant) {
                          TextStyle textStyle =
                              const TextStyle(color: Colors.grey);
                          return ListTile(
                            leading: Text(
                              '${_dbAssistants.length + 1} ',
                              style: textStyle,
                            ),
                            title: Text(
                              assistant.name ??
                                  AppLocalizations.of(context)!.homepage_noName,
                              style: textStyle,
                            ),
                            subtitle: Text(
                              assistant.description ??
                                  AppLocalizations.of(context)!
                                      .homepage_noDescription,
                              style: textStyle,
                            ),
                            onTap: () {
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Consumer<SettingsController>(builder:
                                        (context, settingsController, child) {
                                      final openai =
                                          settingsController.openAiClient;
                                      return AlertDialog(
                                        title: Text(assistant.name ?? ''),
                                        content: Text(
                                            AppLocalizations.of(context)!.undo),
                                        actions: [
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              textStyle: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                            ),
                                            child: Text(
                                                AppLocalizations.of(context)!
                                                    .cancel),
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
                                            child: Text(
                                                AppLocalizations.of(context)!
                                                    .confirm),
                                            onPressed: () async {
                                              bool isSuccess =
                                                  await openai.createAssistant(
                                                      name: assistant.name,
                                                      description:
                                                          assistant.description,
                                                      model: assistant.model,
                                                      instructions: assistant
                                                          .instructions,
                                                      topP: assistant.topP,
                                                      temperature:
                                                          assistant.temperature,
                                                      tools: assistant.tools);
                                              if (isSuccess) {
                                                _deleteAssistant(assistant.id);
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
                              await _showDeleteDialog(context, assistant, true);
                            },
                          );
                        })
                      ]),
                    ),
                  )
              ],
            ),
          ),
        ],
      );
    });
  }
}
