import 'package:flutter/material.dart';
import 'package:openai/src/services/openai_client.dart';
import 'package:openai/src/services/assistant_response_classes.dart';

class ListMessages extends StatefulWidget {
  final String threadId;
  final OpenAiClient openai;
  const ListMessages({super.key, required this.threadId, required this.openai});

  @override
  State<ListMessages> createState() => _ListMessagesState();
}

class _ListMessagesState extends State<ListMessages> {
  late String threadId = widget.threadId;
  late OpenAiClient openai = widget.openai;

  Future<List<Message>> loadMessages({String? after, String? before}) async {
    return await openai.listMessages(threadId: threadId, limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: FutureBuilder<List<Message>>(
        future: loadMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No messages found',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            );
          } else {
            List<Message> messageList = snapshot.data!;
            return ListView.builder(
              reverse: true,
              itemCount: messageList.length,
              itemBuilder: (context, index) {
                final Message message = messageList[index];
                final bool isUser = message.role == 'user';
                final String messageContent =
                    message.content?.isNotEmpty == true
                        ? (message.content!.first is TextContent
                            ? (message.content!.first as TextContent).value
                            : 'Unsupported content type')
                        : 'Empty content';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      color: isUser
                          ? Theme.of(context).cardColor
                          : Theme.of(context).colorScheme.onSecondary,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(5),
                          topLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                        ),
                      ),
                      elevation: 20,
                      clipBehavior: Clip.hardEdge,
                      margin: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 10),
                      child: InkWell(
                        onLongPress: () async {
                          await openai
                              .deleteMessage(
                                  threadId: threadId, msgId: message.id)
                              .then((value) => setState(() {}));
                        },
                        child: Text(
                          messageContent,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
