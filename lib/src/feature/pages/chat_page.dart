import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:openai/src/feature/seperate_pages/api_list_messages.dart';
import 'package:openai/src/feature/seperate_pages/assistant_detail_page.dart';
import 'package:openai/src/services/openai_client.dart';
import 'package:openai/src/services/assistant_response_classes.dart';
import 'package:openai/src/settings/chat_state_provider.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  final String? threadID;
  final Assistant assistant;
  const ChatPage({
    super.key,
    this.threadID,
    required this.assistant,
  });
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late TextEditingController _textController;
  final _scrollController = ScrollController();
  late final OpenAiClient _openai;
  late final Assistant _assistant = widget.assistant;
  late final String _apiKey;
  late final User _user;
  late String threadId = '';
  late MessageService messageService;
  bool _isInstanceReady = false;
  late Stream<List<Message>> _messagesStream;
  ChatState? _chatState;
  bool _showAdditionIcons = false;
  late ReqMessage _request;
  late double temperature = _assistant.temperature!.toDouble();
  late double topP = _assistant.topP!.toDouble();
  int? maxPromptTokens;
  int? maxCompletionTokens;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_handleTextChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsController =
          Provider.of<SettingsController>(context, listen: false);
      _chatState = Provider.of<ChatState>(context, listen: false);
      setState(() {
        _openai = settingsController.openAiClient;
        _apiKey = settingsController.apiKey!;
        _user = settingsController.currentUser!;
      });
      if (widget.threadID != null) {
        threadId = widget.threadID!;
        collectionSet(threadId);
      } else {
        createThread();
      }
      _scrollController.addListener(_updateStream);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    if (_chatState != null) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _chatState!.unsubscribeFromRuns();
          _chatState!.resetState();
        });
      }
    }
    super.dispose();
  }

  void _handleTextChange() {
    ///convert to Additional Instruction
    if (_textController.text.startsWith('@')) {
      _chatState!
          .setTempAdditionalInstruction(_textController.text.substring(1));
    } else {
      _chatState!.setUserText(_textController.text);
    }
  }

  void _updateStream() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _chatState!.setLimitListItems(_chatState!.limitListItems + 20);
      _messagesStream =
          messageService.messageStream(_chatState!.limitListItems); // 스트림 업데이트
    }
  }

  void collectionSet(String threadId) {
    _chatState!.setThreadDismissed(false);
    _chatState!.setUserMessage(null);
    setState(() {
      messageService =
          MessageService(_user.uid, _apiKey, _assistant.id, threadId);
      _chatState!.setLimitListItems(20);
      _messagesStream =
          messageService.messageStream(_chatState!.limitListItems);
      _isInstanceReady = true;
    });
  }

  Future<void> createThread() async {
    Thread newThread = await _openai.createThread();
    _chatState!.setThread(newThread);
    _chatState!.setEmptyThread(true);
    setState(() {
      threadId = newThread.id!;
    });
    collectionSet(threadId);
  }

  Future<void> deleteThread() async {
    await _openai.deleteThread(threadId: threadId);
    await createThread();
    try {
      final collectionRef = FirebaseFirestore.instance
          .collection(_user.uid)
          .doc(_apiKey)
          .collection(_assistant.id);
      DocumentReference docRef = collectionRef.doc(threadId);
      await docRef.delete();
    } catch (e) {
      return;
    }
  }

  Future<void> openThreadsList() async {
    if (_isInstanceReady) {
      final selectedThreadId = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ThreadsListPage(
            assistant: _assistant,
            currentThreadId: threadId,
            apiKey: _apiKey,
            openai: _openai,
            userId: _user.uid,
          ),
        ),
      );

      if (selectedThreadId != null) {
        if (selectedThreadId == 'createThread') {
          await createThread();
        } else {
          _chatState!.setEmptyThread(false);
          threadId = selectedThreadId;
          collectionSet(threadId);
          try {
            final resThread = await _openai.retrieveThread(threadId: threadId);
            if (mounted) {
              _chatState!.setThreadDismissed(false);
              _chatState!.setThread(resThread);
            }
          } catch (e) {
            if (mounted) {
              _chatState!.setThreadDismissed(true);
            }
          }
        }
      }
    }
  }

  // API 요청을 만드는 함수
  ReqMessage createReqMessage(List<ContentItem> contentItems,
      {Role? role, List<String>? attachments, Map<String, String>? metadata}) {
    var content = contentItems.map((item) {
      if (item is TextContent) {
        return item.toRequestJson();
      } else {
        return item.toJson();
      }
    }).toList();

    return ReqMessage(
        role: role,
        content: content,
        attachments: attachments,
        metadata: metadata);
  }

  Future<void> pushMessage({
    required ReqMessage request,
    List<AdditionalMessage>? additionalMessages,
    String? additionalInstructions,
    bool editMode = false,
    num? topP,
    num? temperature,
  }) async {
    _chatState!.setShowController(false);
    if (threadId == '') return;
    _chatState!.setMessaging(true);
    final Message newMessage =
        await _openai.createMessage(threadId: threadId, req: request);
    _chatState!.setUserMessage(newMessage);

    if (_chatState!.emptyThread) {
      try {
        await messageService.addThread(_chatState!.thread!);

        _chatState!.setEmptyThread(false);
      } catch (e) {
        return;
      }
    }

    await messageService.setUserMessage(_chatState!.userMessage!);
    subscribeToEvents(
      _chatState!.userMessage!,
      _openai.createRunAndListenToEvents(
        assistantId: _assistant.id,
        threadId: threadId,
        additionalMessages: additionalMessages,
        additionalInstructions: additionalInstructions,
        topP: topP,
        temperature: temperature,
        maxPromptTokens: maxPromptTokens,
        maxCompletionTokens: maxCompletionTokens,
      ),
    );
  }

  Future<void> regenMessage({
    ReqMessage? request,
    required Message oldMessage,
    required int index,
    bool? editMode = false,
    List<AdditionalMessage>? additionalMessages,
    String? additionalInstructions,
    num? topP,
    num? temperature,
  }) async {
    _chatState!.setShowController(false);
    _chatState!.setMessaging(true);
    _chatState!.setEditMode(value: false);
    _chatState!.setUserMessage(oldMessage);
    try {
      if (index >= 1) {
        await deleteMessage(index - 1);
      }
    } catch (e) {
      e.toString();
    }
    List<Message> messages =
        await _openai.listMessages(threadId: threadId, before: oldMessage.id);

    for (Message msg in messages) {
      await _openai.deleteMessage(threadId: threadId, msgId: msg.id);
    }

    final Message message;
    if (editMode == true) {
      await _openai.deleteMessage(threadId: threadId, msgId: oldMessage.id);

      message = await _openai.createMessage(threadId: threadId, req: request!);

      await messageService.replaceUserMessage(
          oldMessage: oldMessage, newMessage: message);
      _chatState!.setUserMessage(message);
    } else {
      message = oldMessage;
    }

    subscribeToEvents(
      message,
      _openai.createRunAndListenToEvents(
        assistantId: _assistant.id,
        threadId: threadId,
        additionalMessages: additionalMessages,
        additionalInstructions: additionalInstructions,
        topP: topP,
        temperature: temperature,
        maxPromptTokens: maxPromptTokens,
        maxCompletionTokens: maxCompletionTokens,
      ),
    );
  }

  Future<void> deleteMessage(int selectedIndex) async {
    if (selectedIndex >= 0) {
      List<Message> snapshotData = _chatState!.userMessageList!;

      if (selectedIndex < snapshotData.length) {
        var deleteTasks = <Future>[];

        for (int index = 0; index <= selectedIndex; index++) {
          Message message = snapshotData[index];

          var deleteTask = messageService._colRef
              .doc(message.id)
              .delete()
              .catchError((error) {});

          deleteTasks.add(deleteTask);
        }

        // 모든 삭제 작업을 병렬로 처리
        await Future.wait(deleteTasks);
      }
    }
  }

  void subscribeToEvents(
      Message userMessage, Stream<Map<String, dynamic>> eventStream) {
    _chatState!.setStreamingText('');
    _chatState!.removeAdditionalMessages();
    _chatState!.applyInstruction(false);
    setState(() {
      topP = _assistant.topP!.toDouble();
      temperature = _assistant.temperature!.toDouble();
    });
    eventStream.listen((eventData) {
      handleEvent(userMessage, eventData['event'], eventData['data']);
    });
  }

  void handleEvent(
      Message userMessage, String event, Map<String, dynamic> data) async {
    switch (event) {
      //https://platform.openai.com/docs/api-reference/assistants-streaming/events#assistants-streaming/events-thread-created
      case 'thread.created':
        break;
      case 'thread.run.created':
        await messageService.addRun(userMessage.id, Run.fromJson(data));
        _chatState!.setRun(Run.fromJson(data));
        break;
      case 'thread.run.queued':
        _chatState!.setRun(Run.fromJson(data));
        break;
      case 'thread.run.in_progress':
        _chatState!.setRun(Run.fromJson(data));
        break;
      case 'thread.run.requires_action':
        break;
      case 'thread.run.cancelling':
        _chatState!.setMessaging(false);
        break;
      case 'thread.run.cancelled':
        _chatState!.setMessaging(false);
        break;
      case 'thread.run.expired':
        _chatState!.setMessaging(false);
        break;
      case 'thread.run.failed':
        _chatState!.setRun(Run.fromJson(data));
        _chatState!.setErrorMessage(data['last_error']['code']);
        _chatState!.setRateLimitExceeded(true);
        _chatState!.setMessaging(false);
        break;
      case 'thread.run.step.created':
        break;

      case 'thread.run.step.in_progress':
        break;
      case 'thread.run.step.delta':
        break;
      case 'thread.run.step.failed':
        break;
      case 'thread.run.step.cancelled':
        break;

      case 'thread.message.created':
        await messageService.addAssistantMessage(
            userMessage.id, Message.fromJson(data));
      case 'thread.message.in_progress':
        break;

      case 'thread.message.delta':
        HapticFeedback.lightImpact();
        _chatState!.setStreamingText(_chatState!.streamingText +
            data['delta']['content'][0]['text']['value']);
        break;
      case 'thread.message.completed':
        await messageService.updateAssistantMessage(
            userMessage.id, Message.fromJson(data));
        break;
      case 'thread.message.incomplete':
        await messageService.updateAssistantMessage(
            userMessage.id, Message.fromJson(data));
        break;
      case 'thread.run.step.completed':
        break;
      case 'thread.run.completed':
        await messageService.updateRun(userMessage, Run.fromJson(data));

        break;
      case 'error':
        break;
      case 'done':
        _chatState!.setRun(null);
        _chatState!.setMessaging(false);
        _chatState!.setUserMessage(null);
        break;
      default:
        break;
    }
  }

//TODO 만료된 쓰레드에서 이어서 대화하기 기능 추가.

  Widget iconRow() {
    return Row(
      children: <Widget>[
        IconButton(icon: const Icon(Icons.remove), onPressed: () {}),
        IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                _assistant.name!,
                textWidthBasis: TextWidthBasis.parent,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tooltip(
              message: _isInstanceReady
                  ? 'assistant_id: ${widget.assistant.id}\nthread_id: $threadId'
                  : '',
              onTriggered: () {},
              triggerMode: TooltipTriggerMode.tap,
              child: const Icon(
                Icons.info,
                size: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ListMessages(openai: _openai, threadId: threadId)));
              },
              icon: const Icon(Icons.history_rounded)),
          PopupMenuButton(itemBuilder: (context) {
            return [
              const PopupMenuItem<int>(value: 0, child: Text('Assistant Info')),
              const PopupMenuItem<int>(value: 1, child: Text('Thread List')),
              const PopupMenuItem<int>(value: 2, child: Text("Thread Delete")),
            ];
          }, onSelected: (value) {
            if (value == 0) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssistantDetailsPage(
                      assistant: widget.assistant,
                    ),
                  ));
            } else if (value == 1) {
              _isInstanceReady ? openThreadsList() : null;
            } else if (value == 2) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text(
                        'Are you sure you want to delete this thread?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await deleteThread().then((onValue) =>
                                  Navigator.of(context)
                                      .pop() // Close the dialog
                              );
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            }
          }),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatState>(
              builder: (context, chatState, child) {
                return _isInstanceReady
                    ? StreamBuilder<List<Message>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {}
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {}
                          if (snapshot.hasData && snapshot.data != null) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) async {
                              _chatState!.setUserMessageList(snapshot.data!);
                            });
                            if (snapshot.data!.isEmpty) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) async {
                                _chatState!.setEmptyThread(true);
                              });

                              return const Center(
                                child: Icon(Icons.format_quote_rounded),
                              );
                            } else {
                              return ListView.builder(
                                controller: _scrollController,
                                itemCount: chatState.userMessageList!.length,
                                reverse: true,
                                itemBuilder: (context, index) {
                                  Message message =
                                      chatState.userMessageList![index];

                                  return ChatBubble(
                                    key: ValueKey(message.id),
                                    regenerateFunction: regenMessage,
                                    createReqMessage: createReqMessage,
                                    chatState: chatState,
                                    textController: _textController,
                                    assistantId: _assistant.id,
                                    index: index,
                                    message: message,
                                    messageService: messageService,
                                  );
                                },
                              );
                            }
                          } else {
                            return const SizedBox();
                          }
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      );
              },
            ),
          ),
          customTextField()
        ],
      ),
    );
  }

  Widget customTextField() {
    return Consumer<ChatState>(builder: (context, chatState, child) {
      double rightIconSize = 35;
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
        child: Column(
          children: [
            if (chatState.showController)
              Theme(
                data: ThemeData.light(),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              chatState.editMessageMode
                                  ? 'Edit Message'
                                  : 'Controller',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                                onPressed: () {
                                  if (chatState.editMessageMode) {
                                    _textController.text = '';
                                  }
                                  chatState.setEditMode(value: false);
                                },
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                icon: const Icon(Icons.cancel)
                                    .animate()
                                    .fadeIn(duration: 200.ms)),
                          ],
                        ),
                        if (chatState.editMessageMode)
                          Text(
                            chatState.userMessage?.id ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    Theme.of(context).scaffoldBackgroundColor),
                          ),
                        const SizedBox(
                          height: 4,
                        ),
                        Row(
                          children: [
                            Text('top_p: $topP',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor)),
                          ],
                        ),
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Slider(
                                value: topP,
                                max: 1,
                                divisions: 100,
                                onChanged: (value) {
                                  setState(() {
                                    topP = value;
                                  });
                                },
                                label: topP.toString(),
                                secondaryTrackValue:
                                    _assistant.topP!.toDouble(),
                              ),
                              if (topP != _assistant.topP!.toDouble())
                                GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        topP = _assistant.topP!.toDouble();
                                      });
                                    },
                                    child: const Icon(
                                        Icons.settings_backup_restore_rounded)),
                            ],
                          ),
                        ),
                        Text('temperature: $temperature',
                            style: TextStyle(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor)),
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Slider(
                                value: temperature,
                                max: 2,
                                divisions: 200,
                                onChanged: (value) {
                                  setState(() {
                                    temperature = value;
                                  });
                                },
                                label: temperature.toString(),
                                secondaryTrackValue:
                                    _assistant.temperature!.toDouble(),
                              ),
                              if (temperature !=
                                  _assistant.temperature!.toDouble())
                                GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        temperature =
                                            _assistant.temperature!.toDouble();
                                      });
                                    },
                                    child: const Icon(
                                        Icons.settings_backup_restore_rounded))
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  int? tokens;
                                  return AlertDialog(
                                    title: const Text('Set Max Prompt Tokens'),
                                    content: TextField(
                                      keyboardType: TextInputType.number,
                                      autofocus: true,
                                      onChanged: (value) {
                                        if (value.toString().isNotEmpty) {
                                          tokens = int.parse(value);
                                        } else {
                                          tokens = null;
                                        }
                                      },
                                      onSubmitted: (value) {
                                        maxPromptTokens = int.parse(value);
                                        Navigator.pop(context);
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Cancle')),
                                      TextButton(
                                          onPressed: () {
                                            maxPromptTokens = tokens;

                                            Navigator.pop(context);
                                          },
                                          child: const Text('Set'))
                                    ],
                                  );
                                });
                          },
                          child: maxPromptTokens == null
                              ? const Text('Set Max Prompt Tokens')
                              : Text('Max Prompt Tokens: $maxPromptTokens'),
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  int? tokens;
                                  return AlertDialog(
                                    title:
                                        const Text('Set Max Completion Tokens'),
                                    content: TextField(
                                      keyboardType: TextInputType.number,
                                      autofocus: true,
                                      onChanged: (value) {
                                        if (value.toString().isNotEmpty) {
                                          tokens = int.parse(value);
                                        } else {
                                          tokens = null;
                                        }
                                      },
                                      onSubmitted: (value) {
                                        maxCompletionTokens = int.parse(value);
                                        Navigator.pop(context);
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Cancle')),
                                      TextButton(
                                          onPressed: () {
                                            maxCompletionTokens = tokens;

                                            Navigator.pop(context);
                                          },
                                          child: const Text('Set'))
                                    ],
                                  );
                                });
                          },
                          child: maxCompletionTokens == null
                              ? const Text('Set Max Completion Tokens')
                              : Text(
                                  'Max Completion Tokens: $maxCompletionTokens'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            if (chatState.additionalMessages.isNotEmpty)
              ...List<Widget>.generate(chatState.additionalMessages.length,
                  (index) {
                AdditionalMessage additionalMessage =
                    chatState.additionalMessages[index];
                String content = additionalMessage.content;
                String role =
                    additionalMessage.role == Role.user ? 'user' : 'assistant';
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  tileColor: Theme.of(context).colorScheme.onSecondary,
                  title: Row(
                    children: [
                      const Icon(Icons.south_east_rounded),
                      Text('Additional Messages ($role)'),
                    ],
                  ),
                  subtitle: Text(
                    content,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                      onPressed: () {
                        chatState.additionalMessages.remove(additionalMessage);
                      },
                      icon: const Icon(Icons.cancel)),
                );
              }),
            if (chatState.applyAdditionalInstructions)
              ListTile(
                dense: true,
                onTap: () {
                  _textController.text = '@${chatState.additionalInstructions}';
                },
                subtitle: Text(
                  chatState.additionalInstructions,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.data_object_outlined),
                    Text('Additional Instructions'),
                  ],
                ),
                trailing: IconButton(
                    onPressed: () {
                      chatState.applyInstruction(false);
                    },
                    icon: const Icon(Icons.cancel)),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.linear,
                  width: _showAdditionIcons ? 140 : 48,
                  height: 48,
                  child: FittedBox(
                    fit: BoxFit.contain, // 너비에 맞춰 아이콘 크기 조절
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_showAdditionIcons)
                          if (!_showAdditionIcons)
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() {
                                _showAdditionIcons = true;
                              }),
                            ),
                        if (_showAdditionIcons)
                          IconButton(
                              tooltip: '컨트롤러',
                              icon: const Icon(Icons.tune_rounded),
                              onPressed: () {
                                chatState.setShowController(
                                    !chatState.showController);
                              }),
                        if (_showAdditionIcons)
                          IconButton(
                              tooltip: '사진추가',
                              icon:
                                  const Icon(Icons.add_photo_alternate_rounded),
                              onPressed: () => setState(() {
                                    _showAdditionIcons = !_showAdditionIcons;
                                  })),
                        if (_showAdditionIcons)
                          IconButton(
                              tooltip: '파일추가',
                              icon: const Icon(Icons.attach_file_rounded),
                              onPressed: () => setState(() {
                                    _showAdditionIcons = !_showAdditionIcons;
                                  })),
                      ],
                    ),
                  ),
                ),
                Expanded(
                    child: TextField(
                  onTap: () => setState(() {
                    _showAdditionIcons = false;
                  }),
                  onChanged: (v) {
                    setState(() {
                      _showAdditionIcons = false;
                    });
                  },
                  enabled: !chatState.threadDismissed,
                  maxLines: 10,
                  minLines: 1,
                  style: Theme.of(context).textTheme.labelLarge,
                  controller: _textController,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    // prefixIcon: const Icon(Icons.star),
                    hintFadeDuration: const Duration(milliseconds: 300),
                    hintText: chatState.rateLimitExceeded
                        ? chatState.errorMessage
                        : chatState.threadDismissed
                            ? 'ThreadDismissed!'
                            : 'Message',
                    hintStyle: TextStyle(
                      color: chatState.rateLimitExceeded
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).textTheme.bodySmall!.color,
                    ),
                    filled: !chatState.threadDismissed,
                    fillColor: chatState.editMessageMode
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(27)),
                    ),
                  ),
                )),
                (chatState.tempInstructions.isEmpty)
                    ? (chatState.userText.isEmpty ||
                            _textController.text.startsWith('@'))
                        ? IconButton(
                            onPressed: chatState.messaging
                                ? chatState.run != null
                                    ? () {
                                        _openai.cancleRun(
                                            threadId: threadId,
                                            runId: chatState.run!.id);
                                      }
                                    : () {}
                                : null,
                            icon: chatState.messaging
                                ? Icon(
                                    chatState.run != null
                                        ? Icons.stop_circle_outlined
                                        : Icons.circle,
                                    size: rightIconSize,
                                  )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(),
                                    )
                                    .scale(
                                      duration: 500.ms,
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.1, 1.1),
                                    )
                                    .then(duration: 200.ms)
                                    .scale(
                                      begin: const Offset(1.1, 1.1),
                                      end: const Offset(0.9, 0.9),
                                    )
                                : Icon(
                                    Icons.circle,
                                    size: rightIconSize,
                                  ),
                          )
                        : IconButton(
                            icon: chatState.rateLimitExceeded
                                ? Icon(
                                    FontAwesomeIcons.circleExclamation,
                                    size: rightIconSize,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
                                  ).animate().fadeIn(duration: 200.ms)
                                : Icon(Icons.arrow_circle_up_rounded,
                                        size: rightIconSize)
                                    .animate()
                                    .fadeIn(duration: 200.ms),
                            onPressed: () async {
                              if (!chatState.messaging) {
                                final text = _textController.text;
                                _textController.clear();
                                _request = createReqMessage(
                                    [TextContent(value: text)],
                                    role: Role.user);
                                if (chatState.editMessageMode) {
                                  (await regenMessage(
                                      oldMessage: chatState.userMessage!,
                                      index: chatState.editIndex!,
                                      request: _request,
                                      editMode: true,
                                      topP: topP,
                                      temperature: temperature,
                                      additionalMessages: chatState
                                              .additionalMessages.isNotEmpty
                                          ? chatState.additionalMessages
                                          : null,
                                      additionalInstructions: chatState
                                              .additionalInstructions.isNotEmpty
                                          ? chatState.additionalInstructions
                                          : null));
                                  setState(() {
                                    topP = _assistant.topP!.toDouble();
                                    temperature =
                                        _assistant.temperature!.toDouble();
                                  });
                                } else {
                                  (await pushMessage(
                                      request: _request,
                                      topP: topP,
                                      temperature: temperature,
                                      additionalMessages: chatState
                                              .additionalMessages.isNotEmpty
                                          ? chatState.additionalMessages
                                          : null,
                                      additionalInstructions: chatState
                                              .additionalInstructions.isNotEmpty
                                          ? chatState.additionalInstructions
                                          : null));
                                }
                              }
                            },
                          )
                    : IconButton(
                        onPressed: () {
                          chatState.applyInstruction(true);
                          if (chatState.userText != '') {
                            _textController.text = chatState.userText;
                          } else {
                            _textController.clear();
                          }
                        },
                        icon: Icon(
                          Icons.add_circle_rounded,
                          size: rightIconSize,
                        )),
              ],
            ),
          ],
        ),
      );
    });
  }
}

////////////////////////////////////////////////////////////////////////

class ChatBubble extends StatefulWidget {
  final Function({
    ReqMessage? request,
    required Message oldMessage,
    required int index,
    bool? editMode,
    List<AdditionalMessage>? additionalMessages,
    String? additionalInstructions,
    num? topP,
    num? temperature,
  }) regenerateFunction;
  final Function(List<ContentItem> contentItems,
      {Role? role,
      List<String>? attachments,
      Map<String, String>? metadata}) createReqMessage;
  final ChatState chatState;
  final TextEditingController textController;
  final String assistantId;
  final int index;
  final Message message;
  final MessageService messageService;

  const ChatBubble(
      {super.key,
      required this.regenerateFunction,
      required this.createReqMessage,
      required this.chatState,
      required this.textController,
      required this.assistantId,
      required this.index,
      required this.message,
      required this.messageService});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  late final Function({
    ReqMessage? request,
    required Message oldMessage,
    required int index,
    bool? editMode,
    List<AdditionalMessage>? additionalMessages,
    String? additionalInstructions,
    num? topP,
    num? temperature,
  }) regenerateFunction = widget.regenerateFunction;
  late final Function(List<ContentItem> contentItems,
          {Role? role,
          List<String>? attachments,
          Map<String, String>? metadata}) createReqMessage =
      widget.createReqMessage;
  late final ChatState chatState = widget.chatState;
  late final TextEditingController textController = widget.textController;
  late final String assistantId = widget.assistantId;
  late final OpenAiClient _openai;
  late final MessageService messageService = widget.messageService;
  late final int _index = widget.index;
  late Message userMessage = widget.message;
  late ReqMessage request;
  late String userContentText;
  ChatState? _chatState;
  bool _isSelectableAstText = false;
  bool _isSelectableUserText = false;
  bool _showUserMenu = false;
  bool _showAssistantMenu = false;
  bool _showController = false;
  double? topP;
  double? temperature;

  final Map<String, Map<String, double>> modelPricing = {
    "gpt-4o": {"Input": 5, "Output": 15},
    "gpt-4": {"Input": 10, "Output": 30},
    "gpt-3.5": {"Input": 0.50, "Output": 1.50}
  };

  final double princesPer = 1000000.0;
  dynamic calculateCost(
      {required String model,
      Usage? usage,
      int? maxPromptTokens,
      int? maxCompletionTokens}) {
    Map<String, String> costResults = {
      'prompt_tokens': '{\$0}',
      'completion_tokens': '{\$0}',
      'total_tokens': '{\$0}'
    };
    double inputCost = 0.0;
    double outputCost = 0.0;
    for (String key in modelPricing.keys) {
      if (model.contains(key)) {
        inputCost = modelPricing[key]!['Input']!;
        outputCost = modelPricing[key]!['Output']!;
        break;
      }
    }
    if (maxPromptTokens != null || maxCompletionTokens != null) {
      if (maxPromptTokens != null) {
        double promptTokensCost = (maxPromptTokens / princesPer) * inputCost;
        String cost = '\$${promptTokensCost.toStringAsFixed(6)}';
        return cost;
      } else if (maxCompletionTokens != null) {
        double completionTokensCost =
            (maxCompletionTokens / princesPer) * outputCost;
        String cost = '\$${completionTokensCost.toStringAsFixed(6)}';
        return cost;
      }
    }
    if (usage != null) {
      double promptTokensCost = (usage.promptTokens / princesPer) * inputCost;
      double completionTokensCost =
          (usage.completionTokens / princesPer) * outputCost;
      double totalTokensCost = promptTokensCost + completionTokensCost;
      costResults['prompt_tokens'] = '\$${promptTokensCost.toStringAsFixed(6)}';
      costResults['completion_tokens'] =
          '\$${completionTokensCost.toStringAsFixed(6)}';
      costResults['total_tokens'] = '\$${totalTokensCost.toStringAsFixed(6)}';
      return costResults;
    }
  }

  @override
  void initState() {
    super.initState();
    initializeUserContentText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatState ??= Provider.of<ChatState>(context, listen: false);
        final settingsController =
            Provider.of<SettingsController>(context, listen: false);
        setState(() {
          _openai = settingsController.openAiClient;
          final apiKey = settingsController.apiKey!;
          final user = settingsController.currentUser!;
          _chatState!.subscribeToRuns(user.uid, apiKey, assistantId,
              userMessage.threadId, userMessage.id);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void initializeUserContentText() async {
    setState(() {
      userContentText = userMessage.content?.isNotEmpty == true
          ? (userMessage.content!.first is TextContent
              ? (userMessage.content!.first as TextContent).value
              : '지원되지 않는 콘텐츠 타입입니다.')
          : '1';
    });
  }

  Future<void> updateMessage(Message message) async {
    Message recentMessage = await _openai.retrieveMessage(
        threadId: message.threadId, messageId: message.id);
    await messageService.addAssistantMessage(userMessage.id, recentMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 8, 8, 0),
          child: Align(
            alignment: Alignment.topRight,
            child: Card(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(5),
                  topLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              elevation: 4,
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onLongPress: () {
                  AdditionalMessage value = AdditionalMessage(
                      role: Role.user, content: userContentText);
                  chatState.addAdditionalMessages(value);
                },
                onTap: _isSelectableUserText
                    ? null
                    : () => setState(() {
                          _showUserMenu = !_showUserMenu;
                        }),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: _isSelectableUserText
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isSelectableUserText
                          ? Row(
                              children: [
                                const SizedBox(width: 18),
                                Text(
                                  '텍스트선택',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const Expanded(child: SizedBox()),
                                IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isSelectableUserText = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close))
                              ],
                            )
                          : const SizedBox(),
                      _isSelectableUserText
                          ? Container(
                              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(10)),
                              child: SelectableText(userContentText))
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                              child: Text(userContentText),
                            ),
                      (_isSelectableUserText || _showUserMenu)
                          ? const SizedBox()
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                timeInterpreter(userMessage.createdAt,
                                    format: 'HH:mm'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                      if (_showUserMenu)
                        Container(
                          margin: const EdgeInsets.fromLTRB(5, 12, 5, 5),
                          decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: '텍스트선택',
                                    icon: const Icon(
                                        Icons.document_scanner_outlined),
                                    onPressed: () {
                                      setState(() {
                                        _isSelectableUserText = true;
                                        _showUserMenu = false;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '전체복사',
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: userContentText));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '수정',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      chatState.setEditMode(
                                          value: true,
                                          index: _index,
                                          userMessage: userMessage);
                                      textController.text = userContentText;
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '재생성',
                                    icon: const Icon(Icons.refresh_rounded),
                                    onPressed: () {
                                      request = createReqMessage(
                                          userMessage.content ?? [],
                                          role: Role.user);
                                      widget.regenerateFunction(
                                        request: request,
                                        oldMessage: userMessage,
                                        index: _index,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'id: ${userMessage.id}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: true,
            child: Consumer<ChatState>(builder: (context, chatState, child) {
              return replyItem(chatState);
            }),
          ),
        ),
      ],
    );
  }

  Widget replyItem(ChatState chatState) {
    List runMessages = chatState.getRunMessages(userMessage.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(runMessages.length, (index) {
        final Map<Run, Message> runMessage = runMessages[index];

        return Row(
          children: runMessage.entries.map((entry) {
            final Run run = entry.key;
            final Message message = entry.value;
            Usage? usage = run.usage;
            String model = run.model?.toString() ?? '';
            int? maxPromptTokens = run.maxPromptTokens;
            int? maxCompletionTokens = run.maxCompletionTokens;
            late String assistantContentText = '';

            if (topP == null || temperature == null) {
              topP = run.topP!.toDouble();
              temperature = run.temperature!.toDouble();
            }

            if (userMessage.id == chatState.userMessage?.id &&
                index == 0 &&
                !chatState.editMessageMode) {
              assistantContentText = chatState.streamingText;
            } else {
              if (assistantContentText.isEmpty &&
                  message.content?.isNotEmpty == true) {
                assistantContentText = (message.content!.first is TextContent)
                    ? (message.content!.first as TextContent).value
                    : '지원되지 않는 콘텐츠 타입입니다.';
              } else if (assistantContentText.isEmpty &&
                  message.status == 'in_progress') {
                if (mounted) updateMessage(message);
              }
            }

            return Stack(
              children: [
                if (runMessages.length > 1)
                  Positioned(
                      bottom: 8,
                      right: 8,
                      child: Text(
                        '${index + 1}/${runMessages.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                      )),
                Container(
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.fromLTRB(8, 8, 30, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.format_quote_rounded),
                        Flexible(
                          child: Card(
                            color: Theme.of(context).colorScheme.onPrimary,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(15),
                                topLeft: Radius.circular(5),
                                bottomRight: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                              ),
                            ),
                            elevation: 4,
                            clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onLongPress: () {
                                if (!(userMessage.id ==
                                        chatState.userMessage?.id &&
                                    index == 0 &&
                                    !chatState.editMessageMode)) {
                                  AdditionalMessage value = AdditionalMessage(
                                      role: Role.assistant,
                                      content: assistantContentText);
                                  chatState.addAdditionalMessages(value);
                                }
                              },
                              onTap: _isSelectableAstText
                                  ? null
                                  : () => setState(() {
                                        _showAssistantMenu =
                                            !_showAssistantMenu;
                                      }),
                              child: IntrinsicWidth(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isSelectableAstText)
                                      Row(
                                        children: [
                                          const SizedBox(width: 18),
                                          Text(
                                            '텍스트선택',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge,
                                          ),
                                          const Expanded(child: SizedBox()),
                                          IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _isSelectableAstText = false;
                                                });
                                              },
                                              icon: const Icon(Icons.close))
                                        ],
                                      ),
                                    _isSelectableAstText
                                        ? Container(
                                            margin: const EdgeInsets.fromLTRB(
                                                8, 0, 8, 0),
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                                color:
                                                    Theme.of(context).cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: SelectableText(
                                                assistantContentText))
                                        : Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                18, 12, 18, 0),
                                            child: Text(assistantContentText),
                                          ),
                                    if (!_showAssistantMenu)
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: userMessage.id ==
                                                  chatState.userMessage?.id
                                              ? const SizedBox()
                                              : Text(
                                                  timeInterpreter(
                                                      message.createdAt,
                                                      format: 'HH:mm'),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                        ),
                                      ),
                                    if (_showAssistantMenu)
                                      Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            5, 12, 5, 5),
                                        decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                IconButton(
                                                  tooltip: '텍스트선택',
                                                  icon: const Icon(Icons
                                                      .document_scanner_outlined),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isSelectableAstText =
                                                          true;
                                                      _showAssistantMenu =
                                                          false;
                                                    });
                                                  },
                                                ),
                                                IconButton(
                                                  tooltip: '전체복사',
                                                  icon: const Icon(Icons.copy),
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(
                                                        text:
                                                            assistantContentText));
                                                  },
                                                ),
                                                if (_index == 0)
                                                  IconButton(
                                                    tooltip: '재생성',
                                                    icon: const Icon(
                                                        Icons.replay_rounded),
                                                    onPressed: () {
                                                      request = createReqMessage(
                                                          userMessage.content ??
                                                              [],
                                                          role: Role.user);
                                                      regenerateFunction(
                                                          oldMessage:
                                                              userMessage,
                                                          index: _index,
                                                          topP: topP,
                                                          temperature:
                                                              temperature);
                                                    },
                                                  ),
                                                if (_index == 0)
                                                  IconButton(
                                                    tooltip: '컨트롤러',
                                                    icon: const Icon(
                                                        Icons.tune_rounded),
                                                    onPressed: () {
                                                      setState(() {
                                                        _showController =
                                                            !_showController;
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('id: ${message.id}',
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                  Text(
                                                    'model: $model',
                                                    style: const TextStyle(
                                                        fontSize: 11),
                                                  ),
                                                  Text(
                                                    'topP: ${run.topP}',
                                                    style: const TextStyle(
                                                        fontSize: 11),
                                                  ),
                                                  if (_showController)
                                                    Row(
                                                      children: [
                                                        Slider(
                                                          value: topP!,
                                                          max: 1,
                                                          divisions: 100,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              topP = value;
                                                            });
                                                          },
                                                          label:
                                                              topP.toString(),
                                                          secondaryTrackValue:
                                                              run.topP!
                                                                  .toDouble(),
                                                        ),
                                                        if (topP !=
                                                            run.topP!
                                                                .toDouble())
                                                          GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  topP = run
                                                                      .topP!
                                                                      .toDouble();
                                                                });
                                                              },
                                                              child: const Icon(
                                                                  Icons
                                                                      .settings_backup_restore_rounded)),
                                                      ],
                                                    ),
                                                  Text(
                                                    'temperature: ${run.temperature}',
                                                    style: const TextStyle(
                                                        fontSize: 11),
                                                  ),
                                                  if (_showController)
                                                    Row(
                                                      children: [
                                                        Slider(
                                                          value: temperature!,
                                                          max: 2,
                                                          divisions: 200,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              temperature =
                                                                  value;
                                                            });
                                                          },
                                                          label: temperature
                                                              .toString(),
                                                          secondaryTrackValue:
                                                              run.temperature!
                                                                  .toDouble(),
                                                        ),
                                                        if (temperature !=
                                                            run.temperature!
                                                                .toDouble())
                                                          GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  temperature = run
                                                                      .temperature!
                                                                      .toDouble();
                                                                });
                                                              },
                                                              child: const Icon(
                                                                  Icons
                                                                      .settings_backup_restore_rounded))
                                                      ],
                                                    ),
                                                  if (usage != null)
                                                    ...usage
                                                        .toJson()
                                                        .entries
                                                        .map((entry) {
                                                      Map<String, String>
                                                          costs = calculateCost(
                                                        model: model,
                                                        usage: usage,
                                                      );
                                                      String costDisplay =
                                                          costs[entry.key] ??
                                                              "?";
                                                      return Text(
                                                        '${entry.key.replaceAll('_', ' ')}: ${entry.value} tokens ($costDisplay)',
                                                        style: const TextStyle(
                                                            fontSize: 10),
                                                      );
                                                    }),
                                                  if (maxPromptTokens != null)
                                                    Text(
                                                        'max prompt tokens: $maxPromptTokens (${calculateCost(
                                                          model: model,
                                                          maxPromptTokens:
                                                              maxPromptTokens,
                                                        )})',
                                                        style: const TextStyle(
                                                            fontSize: 10)),
                                                  if (maxCompletionTokens !=
                                                      null)
                                                    Text(
                                                        'max completion tokens: $maxCompletionTokens (${calculateCost(
                                                          model: model,
                                                          maxPromptTokens:
                                                              maxCompletionTokens,
                                                        )})',
                                                        style: const TextStyle(
                                                            fontSize: 10))
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        );
      }),
    );
  }
}

////////////////////////////////////////////////////////////////////////
String timeInterpreter(int time, {String format = 'yy/MM/dd HH:mm'}) {
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
  String timestamp = DateFormat(format).format(createdAt);
  return timestamp;
}

////////////////////////////////////////////////////////////////////////
class MessageService {
  final CollectionReference _colRef;
  final DocumentReference _docRef;
  MessageService(
      String userId, String apiKey, String assistantId, String? threadId)
      : _colRef = FirebaseFirestore.instance
            .collection(userId)
            .doc(apiKey)
            .collection(assistantId)
            .doc(threadId)
            .collection('user_messages'),
        _docRef = FirebaseFirestore.instance
            .collection(userId)
            .doc(apiKey)
            .collection(assistantId)
            .doc(threadId);

  Stream<List<Message>> messageStream(int limitItems) {
    return _colRef
        .orderBy('created_at', descending: true)
        .limit(limitItems)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Message.fromJson(doc.data() as Map<String, dynamic>);
            }).toList());
  }

  Stream runStream(String userMsgId) {
    return _colRef.doc(userMsgId).collection('runs').snapshots();
  }

  Future<void> addThread(Thread thread) {
    return _docRef.set(thread.toJson(), SetOptions(merge: true));
  }

  Future<void> setUserMessage(Message message) {
    return _colRef
        .doc(message.id)
        .set(message.toJson(), SetOptions(merge: true));
  }

  Future<void> replaceUserMessage(
      {required Message oldMessage, required Message newMessage}) async {
    await _colRef.doc(oldMessage.id).delete();
    await _colRef
        .doc(newMessage.id)
        .set(newMessage.toJson(), SetOptions(merge: true));
  }

  Future<void> addAssistantMessage(String userMsgId, Message message) async {
    final docRef = _colRef.doc(userMsgId).collection('runs').doc(message.runId);
    try {
      docRef.set({'message': message.toJson()}, SetOptions(merge: true));
    } catch (e) {
      return;
    }
  }

  Future<void> updateAssistantMessage(String userMsgId, Message message) async {
    final docRef = _colRef.doc(userMsgId).collection('runs').doc(message.runId);
    try {
      docRef.update({'message': message.toJson()});
    } catch (e) {
      return;
    }
  }

  Future<void> addRun(String msgId, Run run) async {
    final docRef = _colRef.doc(msgId);
    try {
      await docRef
          .collection('runs')
          .doc(run.id)
          .set({'run': run.toJson()}, SetOptions(merge: true));
      await docRef.update({
        'assistant_id': run.assistantId,
        'run_id': run.id,
      });
    } catch (e) {
      return;
    }
  }

  Future<void> deleteRun(String msgId, Run run) async {
    final docRef = _colRef.doc(msgId);
    try {
      await docRef.collection('runs').doc(run.id).delete();
    } catch (e) {
      return;
    }
  }

  Future<void> updateRun(Message message, Run run) async {
    final docRef = _colRef.doc(message.id);
    try {
      await docRef.collection('runs').doc(run.id).update({'run': run.toJson()});
      await docRef.update({'run_id': run.id});
    } catch (e) {
      return;
    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////

class ThreadsListPage extends StatefulWidget {
  final Assistant assistant;
  final OpenAiClient openai;
  final String userId;
  final String apiKey;
  final String currentThreadId;

  const ThreadsListPage(
      {super.key,
      required this.assistant,
      required this.openai,
      required this.userId,
      required this.apiKey,
      required this.currentThreadId});

  @override
  State<ThreadsListPage> createState() => _ThreadsListPageState();
}

class _ThreadsListPageState extends State<ThreadsListPage> {
  late String? title = widget.assistant.name ?? '이름없음';
  late String assistantId = widget.assistant.id;
  late OpenAiClient openai = widget.openai;
  late String userId = widget.userId;
  late String apiKey = widget.apiKey;
  late String currentThreadId = widget.currentThreadId;
  late CollectionReference collectionRef;

  @override
  void initState() {
    super.initState();
    collectionRef = FirebaseFirestore.instance
        .collection(userId)
        .doc(apiKey)
        .collection(assistantId);
    loadThreadDetails();
  }

  Future<void> deleteThread(String threadId) async {
    DocumentReference docRef = collectionRef.doc(threadId);
    try {
      openai.deleteThread(threadId: threadId);
      await docRef.delete();
    } catch (e) {
      showPopupMessage("Error deleting thread $threadId: $e");
    }
  }

  void showPopupMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<Thread>> loadThreadDetails() async {
    var snapshot =
        await collectionRef.orderBy('created_at', descending: true).get();

    List<Thread> threads = snapshot.docs
        .map((doc) => Thread.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    return threads;
  }

  Future<void> retrieveThreadAndSet({required String threadId}) async {
    try {
      Thread getThread = await openai.retrieveThread(threadId: threadId);
      await collectionRef
          .doc(threadId)
          .set(getThread.toJson(), SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('에러가 발생했습니다: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  ListTile listTile(Thread? thread) {
    if (thread == null || thread.createdAt == null) return const ListTile();

    return ListTile(
      title: Text(
          'Created At: ${timeInterpreter(thread.createdAt!, format: 'MM/dd HH:mm')}'),
      subtitle: Text('ID: ${thread.id}'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.pop(context, thread.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$title'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Hero(
              tag: 'search',
              child: IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.search,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          )
        ],
      ),
      body: FutureBuilder<List<Thread>>(
        future: loadThreadDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            List<Thread> threads = snapshot.data!;
            if (snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('No threads have been created yet'));
            } else {
              return ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  Thread thread = threads[index];
                  if (thread.id == currentThreadId) {
                    return Slidable(
                        key: ValueKey(thread.id),
                        startActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            dragDismissible: false,
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  Navigator.pop(context, currentThreadId);
                                },
                                backgroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                foregroundColor: Colors.white,
                                icon: Icons.arrow_back,
                                label: 'Go back',
                              ),
                            ]),
                        child: listTile(thread));
                  }
                  return Slidable(
                    key: ValueKey(thread.id),
                    startActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      dismissible: DismissiblePane(
                        onDismissed: () async {
                          await deleteThread(thread.id!);
                          setState(() {
                            threads.removeAt(index);
                          });
                        },
                      ),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            await deleteThread(thread.id!);
                            setState(() {
                              threads.removeAt(index);
                            });
                          },
                          backgroundColor: const Color(0xFFFE4A49),
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: 'Delete',
                        ),
                        const SlidableAction(
                          onPressed: null,
                          backgroundColor: Color(0xFF21B7CA),
                          foregroundColor: Colors.white,
                          icon: Icons.archive_rounded,
                          label: 'Archive',
                        ),
                      ],
                    ),
                    child: listTile(thread),
                  );
                },
              );
            }
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return const Center(child: Text('No threads found.'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            Navigator.pop(context, 'createThread');
          } catch (e) {
            throw Exception();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class SearchTextField extends StatefulWidget {
  const SearchTextField(
      {super.key,
      this.onFocusChange,
      this.focus,
      this.onCancel,
      this.inputDecoration});

  final void Function(bool hasFocus)? onFocusChange;
  final FocusNode? focus;
  final VoidCallback? onCancel;
  final InputDecoration? inputDecoration;

  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField> {
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.focus ?? FocusNode();
    _focus.addListener(() {
      if (widget.onFocusChange != null) {
        widget.onFocusChange!(_focus.hasFocus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: "search",
      child: Material(
        type: MaterialType.card,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                focusNode: _focus,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.black,
                  ),
                  // suffixIcon: Text("Cancel"),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
              ),
            ),
            if (widget.onCancel != null)
              GestureDetector(
                onTap: widget.onCancel,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Cancel"),
                ),
              )
          ],
        ),
      ),
    );
  }
}
