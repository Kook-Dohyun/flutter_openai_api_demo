import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:openai/src/services/assistant_response_classes.dart';

class ChatState extends ChangeNotifier {
  String _streamingText = '';
  int _limitListItems = 0;
  String _userText = '';
  bool _messaging = false;
  bool _editMessageMode = false;
  int? _editIndex = 0;
  bool _showController = false;
  bool _error = false;
  String _errorMessage = '';
  bool _threadDismissed = false;
  bool _emptyThread = true;
  Thread? _thread;
  Run? _resRun;
  Message? _userMessage;
  List<Message>? _userMessageList;
  List<AdditionalMessage> _additionalMessages = [];
  String _additionalInstructions = '';
  String _tempInstructions = '';
  bool _applyAdditionalInstructions = false;
  Map<String, StreamSubscription> runSubscriptions = {};
  Map<String, List<Map<Run, Message>>> runMessagesById = {};
  bool _isBottom = true;

  String get streamingText => _streamingText;
  int get limitListItems => _limitListItems;
  String get userText => _userText;
  bool get messaging => _messaging;
  bool get editMessageMode => _editMessageMode;
  int? get editIndex => _editIndex;
  bool get showController => _showController;
  bool get error => _error;
  String get errorMessage => _errorMessage;
  bool get threadDismissed => _threadDismissed;
  bool get emptyThread => _emptyThread;
  Thread? get thread => _thread;
  Run? get run => _resRun;
  Message? get userMessage => _userMessage;
  List<Message>? get userMessageList => _userMessageList;
  List<AdditionalMessage> get additionalMessages => _additionalMessages;
  String get additionalInstructions => _additionalInstructions;
  String get tempInstructions => _tempInstructions;
  bool get applyAdditionalInstructions => _applyAdditionalInstructions;
  bool get isBottom => _isBottom;

  void setStreamingText(String text) {
    _streamingText = text;
    notifyListeners();
  }

  void setLimitListItems(int value) {
    _limitListItems = value;
    notifyListeners();
  }

  void setUserText(String text) {
    _userText = text;
    notifyListeners();
  }

  void setMessaging(bool value) {
    _messaging = value;
    notifyListeners();
  }

  void setEditMode(
      {required bool value, int? index, Message? userMessage, required}) {
    _editMessageMode = value;
    _showController = value;
    _editIndex = index;
    _userMessage = userMessage;
    notifyListeners();
  }

  void setShowController(bool value) {
    _showController = value;
    notifyListeners();
  }

  void setError(bool value) {
    _error = value;
    notifyListeners();
  }

  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setThreadDismissed(bool value) {
    _threadDismissed = value;
    notifyListeners();
  }

  void setEmptyThread(bool value) {
    _emptyThread = value;
    notifyListeners();
  }

  void setThread(Thread? value) {
    _thread = value;
    notifyListeners();
  }

  void setRun(Run? vlaue) {
    _resRun = vlaue;
    notifyListeners();
  }

  void setUserMessage(Message? vlaue) {
    _userMessage = vlaue;
    notifyListeners();
  }

  void setUserMessageList(List<Message>? vlaue) {
    _userMessageList = vlaue;
    notifyListeners();
  }

  void addAdditionalMessages(AdditionalMessage value) {
    _additionalMessages.add(value);
    notifyListeners();
  }

  void removeAdditionalMessages() {
    _additionalMessages = [];
    notifyListeners();
  }

  void setTempAdditionalInstruction(String value) {
    _tempInstructions = value;
    notifyListeners();
  }

  void applyInstruction(bool value) {
    _applyAdditionalInstructions = value;
    if (value) {
      _additionalInstructions = _tempInstructions;
    } else {
      _additionalInstructions = '';
    }
    _tempInstructions = '';
    notifyListeners();
  }

  void setIsBottom(bool value) {
    _isBottom = value;
    notifyListeners();
  }

  void resetState() {
    _streamingText = '';
    _limitListItems = 0;
    _userText = '';
    _messaging = false;
    _editIndex = null;
    _showController = false;
    _editMessageMode = false;
    _error = false;
    _errorMessage = '';
    _threadDismissed = false;
    _emptyThread = true;
    _thread = null;
    _userMessage = null;
    _resRun = null;
    _applyAdditionalInstructions = false;
    _additionalInstructions = '';
    _isBottom = true;
    removeAdditionalMessages();
    notifyListeners();
  }

  List<Map<Run, Message>> getRunMessages(String messageId) {
    return runMessagesById[messageId] ?? [];
  }

  void subscribeToRuns(String userId, String apiKey, String assistantId,
      String threadId, String userMsgId) {
    var stream = FirebaseFirestore.instance
        .collection(userId)
        .doc(apiKey)
        .collection(assistantId)
        .doc(threadId)
        .collection('user_messages')
        .doc(userMsgId)
        .collection('runs')
        .orderBy('message.created_at', descending: true)
        .snapshots();

    runSubscriptions[userMsgId] = stream.listen((snapshot) {
      List<Map<Run, Message>> runMessages =
          snapshot.docs.map((DocumentSnapshot document) {
        Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
        Run run = Run.fromJson(data['run']);
        Message? message = Message.fromJson(data['message']);
        return {run: message};
      }).toList();
      runMessagesById[userMsgId] = runMessages;
      notifyListeners();
    });
  }

  void unsubscribeFromRuns() {
    _userMessageList?.forEach((Message message) {
      String userMsgId = message.id;
      runSubscriptions[userMsgId]?.cancel(); // 해당 ID의 스트림 구독 취소
      runSubscriptions.remove(userMsgId); // 구독 목록에서 해당 ID 제거
      runMessagesById.remove(userMsgId); // 메시지 ID에 관련된 데이터 제거
    });
    _userMessageList?.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (var sub in runSubscriptions.values) {
      sub.cancel();
    }
    runSubscriptions.clear();
    super.dispose();
  }
}
