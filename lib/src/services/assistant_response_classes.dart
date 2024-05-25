class Assistant {
  final String id;
  final String object;
  final int createdAt;
  final String? name;
  final String? description;
  final String model;
  final String? instructions;
  final List<Tool> tools;
  final ToolResources? toolResources;
  final Map<String, dynamic> metadata;
  final num? temperature;
  final num? topP;
  final ResponseFormat? responseFormat;

  Assistant({
    required this.id,
    required this.object,
    required this.createdAt,
    this.name,
    this.description,
    required this.model,
    this.instructions,
    required this.tools,
    this.toolResources,
    required this.metadata,
    this.temperature,
    this.topP,
    this.responseFormat,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created_at': createdAt,
      'name': name,
      'description': description,
      'model': model,
      'instructions': instructions,
      'tools': tools.map((tool) => tool.toJson()).toList(),
      'tool_resources': toolResources?.toJson(),
      'metadata': metadata,
      'temperature': temperature,
      'top_p': topP,
      'response_format': responseFormat?.toJson(),
    };
  }

  factory Assistant.fromJson(Map<String, dynamic> json) {
    return Assistant(
      id: json['id'] as String,
      object: json['object'] as String,
      createdAt: json['created_at'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      model: json['model'] as String,
      instructions: json['instructions'] as String?,
      tools: (json['tools'] as List<dynamic>)
          .map((toolJson) => Tool.fromJson(toolJson as Map<String, dynamic>))
          .toList(), // Correctly creating Tool objects
      toolResources: json['tool_resources'] != null
          ? ToolResources.fromJson(
              json['tool_resources'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>,
      temperature: json['temperature'] as num?,
      topP: json['top_p'] as num?,
      responseFormat: json['response_format'] != null
          ? ResponseFormat.fromJson(json['response_format'])
          : null,
    );
  }
}

class Thread {
  final String? id;
  final String? object;
  final int? createdAt;
  final ToolResources? toolResources;
  final Map<String, dynamic>? metadata;

  Thread({
    this.id,
    this.object,
    this.createdAt,
    this.toolResources,
    this.metadata,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created_at': createdAt,
      'tool_resources': toolResources?.toJson(),
      'metadata': metadata,
    };
  }

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'] as String,
      object: json['object'] as String?,
      createdAt: json['created_at'] as int?,
      toolResources: json['tool_resources'] != null
          ? ToolResources.fromJson(
              Map<String, dynamic>.from(json['tool_resources']))
          : null,
      metadata: json['metadata'] ?? {},
    );
  }
}

class Message {
  final String id;
  final String? object;
  final int createdAt;
  final String threadId;
  final String? status;
  final IncompleteDetails? incompleteDetails;
  final int? completedAt;
  final int? incompleteAt;
  final String role;
  final List<ContentItem>? content;
  final String? assistantId;
  final String? runId;
  final List<Attachment>? attachments;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    this.object,
    required this.createdAt,
    required this.threadId,
    this.status,
    this.incompleteDetails,
    this.completedAt,
    this.incompleteAt,
    required this.role,
    this.content,
    this.assistantId,
    this.runId,
    this.attachments,
    this.metadata,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created_at': createdAt,
      'thread_id': threadId,
      'status': status,
      'incomplete_details': incompleteDetails?.toJson(),
      'completed_at': completedAt,
      'incomplete_at': incompleteAt,
      'role': role,
      'content': content?.map((item) => item.toJson()).toList(),
      'assistant_id': assistantId,
      'run_id': runId,
      'attachments':
          attachments?.map((attachment) => attachment.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory Message.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Message.empty();
    }
    return Message(
      id: json['id'] as String? ?? '',
      object: json['object'] as String?,
      createdAt: json['created_at'] as int? ?? 0,
      threadId: json['thread_id'] as String? ?? '',
      status: json['status'] as String?,
      incompleteDetails: json['incomplete_details'] != null
          ? IncompleteDetails.fromJson(
              json['incomplete_details'] as Map<String, dynamic>)
          : null,
      completedAt: json['completed_at'] as int?,
      incompleteAt: json['incomplete_at'] as int?,
      role: json['role'] as String? ?? '',
      content: (json['content'] as List?)
              ?.map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      assistantId: json['assistant_id'] as String?,
      runId: json['run_id'] as String?,
      attachments: (json['attachments'] as List?)
              ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  factory Message.empty() {
    return Message(
        id: 'default-id',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        threadId: 'default-thread',
        role: 'user',
        content: [], // ContentItem 리스트 초기화
        attachments: [], // Attachment 리스트 초기화
        metadata: {} // 메타데이터 초기화
        );
  }
}

class ReqMessage {
  Role? role;
  dynamic content;
  List<String>? attachments;
  Map<String, String>? metadata;

  ReqMessage(
      {this.role = Role.user,
      required this.content,
      this.attachments,
      this.metadata});

  Map<String, dynamic> toJson() {
    return {
      'role': role != null ? role.toString().split('.').last : 'user',
      'content': content is String ? content : content,
      'attachments': attachments,
      'metadata': metadata,
    };
  }
}

class Run {
  final String id;
  final String assistantId;
  final String threadId;
  final String? object;
  final int? createdAt;
  final String? status;
  final RequiredAction? requiredAction;
  final LastError? lastError;
  final int? expiresAt;
  final int? startedAt;
  final int? cancelledAt;
  final int? failedAt;
  final int? completedAt;
  final IncompleteDetails? incompleteDetails;
  final String? model;
  final String? instructions;
  final List<Tool>? tools;
  final Map<String, dynamic>? metadata;
  final Usage? usage;
  final num? temperature;
  final num? topP;
  final int? maxPromptTokens;
  final int? maxCompletionTokens;
  final TruncationStrategy? truncationStrategy;
  final ToolChoice? toolChoice;
  final ResponseFormat? responseFormat;

  Run(
      {required this.id,
      this.object,
      this.createdAt,
      required this.threadId,
      required this.assistantId,
      this.status,
      this.requiredAction,
      this.lastError,
      this.expiresAt,
      this.startedAt,
      this.cancelledAt,
      this.failedAt,
      this.completedAt,
      this.incompleteDetails,
      required this.model,
      this.instructions,
      this.tools,
      this.metadata,
      this.usage,
      this.temperature,
      this.topP,
      this.maxPromptTokens,
      this.maxCompletionTokens,
      this.truncationStrategy,
      this.toolChoice,
      this.responseFormat});
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "object": object,
      "created_at": 1699075072,
      "assistant_id": assistantId,
      "thread_id": threadId,
      "status": status,
      "started_at": startedAt,
      "expires_at": expiresAt,
      "cancelled_at": cancelledAt,
      "failed_at": failedAt,
      "completed_at": completedAt,
      "last_error": lastError?.toJson(),
      "model": model,
      "instructions": instructions,
      "incomplete_details": incompleteDetails?.toJson(),
      "tools": tools?.map((e) => e.toJson()),
      "metadata": {},
      "usage": usage?.toJson(),
      "temperature": temperature,
      "top_p": topP,
      "max_prompt_tokens": maxPromptTokens,
      "max_completion_tokens": maxCompletionTokens,
      "truncation_strategy": truncationStrategy?.toJson(),
      "response_format": responseFormat?.toJson(),
      "tool_choice": toolChoice?.toJson(),
    };
  }

  factory Run.fromJson(Map<String, dynamic> json) {
    return Run(
      id: json['id'] as String,
      object: json['object'] as String?,
      createdAt: json['created_at'] as int?,
      threadId: json['thread_id'] as String,
      assistantId: json['assistant_id'] as String,
      status: json['status'] as String?,
      requiredAction: json['required_action'] != null
          ? RequiredAction.fromJson(
              json['required_action'] as Map<String, dynamic>)
          : null,
      lastError: json['last_error'] != null
          ? LastError.fromJson(json['last_error'] as Map<String, dynamic>)
          : null,
      expiresAt: json['expires_at'] as int?,
      startedAt: json['started_at'] as int?,
      cancelledAt: json['cancelled_at'] as int?,
      failedAt: json['failed_at'] as int?,
      completedAt: json['completed_at'] as int?,
      incompleteDetails: json['incomplete_details'] != null
          ? IncompleteDetails.fromJson(
              json['incomplete_details'] as Map<String, dynamic>)
          : null,
      usage: json['usage'] != null
          ? Usage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      model: json['model'] as String,
      instructions: json['instructions'] as String?,
      tools: json['tools'] != null
          ? (json['tools'] as List<dynamic>)
              .map(
                  (toolJson) => Tool.fromJson(toolJson as Map<String, dynamic>))
              .toList()
          : null, // Correctly creating Tool objects
      metadata: json['metadata'] != null
          ? json['metadata'] as Map<String, dynamic>
          : null,
      temperature: json['temperature'] as num?,
      topP: json['top_p'] as num?,
      maxPromptTokens: json['max_prompt_tokens'] as int?,
      maxCompletionTokens: json['max_completion_tokens'] as int?,
      truncationStrategy: json['truncation_strategy'] != null
          ? TruncationStrategy.fromJson(
              json['truncation_strategy'] as Map<String, dynamic>)
          : null,
      // toolChoice: json['tool_choice'] as ToolChoice?,
      responseFormat: json['response_format'] != null
          ? ResponseFormat.fromJson(json['response_format'])
          : null,
    );
  }
}

class RunStep {
  final String id;
  final String object;
  final int createdAt;
  final String assistantId;
  final String threadId;
  final String runId;
  final String type;
  final String status;
  final StepDetails stepDetails;
  final LastError? lastError;
  final int? expiredAt;
  final int? cancelledAt;
  final int? failedAt;
  final int? completedAt;
  final Map<String, dynamic> metadata;
  final Usage? usage;

  RunStep({
    required this.id,
    required this.object,
    required this.createdAt,
    required this.assistantId,
    required this.threadId,
    required this.runId,
    required this.type,
    required this.status,
    required this.stepDetails,
    this.lastError,
    this.expiredAt,
    this.cancelledAt,
    this.failedAt,
    this.completedAt,
    required this.metadata,
    this.usage,
  });

  factory RunStep.fromJson(Map<String, dynamic> json) {
    return RunStep(
      id: json['id'] as String,
      object: json['object'] as String,
      createdAt: json['created_at'] as int,
      runId: json['run_id'] as String,
      assistantId: json['assistant_id'] as String,
      threadId: json['thread_id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      cancelledAt: json['cancelled_at'] as int?,
      completedAt: json['completed_at'] as int?,
      expiredAt: json['expired_at'] as int?,
      failedAt: json['failed_at'] as int?,
      lastError: json['last_error'] as LastError?,
      stepDetails: json['step_details'] as StepDetails,
      metadata: json['metadata'] as Map<String, dynamic>,
      usage: json['usage'] as Usage?,
    );
  }
}

class VectorStore {
  final String id;
  final String object;
  final int createdAt;
  final String name;
  final int usageBytes;
  final FileCounts fileCounts;
  final String status;
  final ExpiresAfter expiresAfter;
  final int? expiresAt;
  final int? lastActiveAt;
  final Map<String, dynamic> metadata;

  VectorStore({
    required this.id,
    required this.object,
    required this.createdAt,
    required this.name,
    required this.usageBytes,
    required this.fileCounts,
    required this.status,
    required this.expiresAfter,
    this.expiresAt,
    required this.lastActiveAt,
    required this.metadata,
  });

  factory VectorStore.fromJson(Map<String, dynamic> json) {
    return VectorStore(
      id: json['id'] as String,
      object: json['object'] as String,
      createdAt: json['created_at'] as int,
      name: json['name'] as String,
      usageBytes: json['usage_bytes'] as int,
      fileCounts:
          FileCounts.fromJson(json['file_counts'] as Map<String, dynamic>),
      status: json['status'] as String,
      expiresAfter:
          ExpiresAfter.fromJson(json['expires_after'] as Map<String, dynamic>),
      expiresAt: json['expires_at'] as int?,
      lastActiveAt: json['last_active_at'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }
}

class VectorStoreFile {
  final String id;
  final String object; // 항상 'vector_store.file' 값으로 설정
  final int usageBytes;
  final int createdAt;
  final String vectorStoreId;
  final String
      status; // 'in_progress', 'completed', 'cancelled', 'failed' 중 하나의 값을 가짐
  final LastError? lastError; // LastError 클래스 인스턴스, 에러가 없으면 null

  VectorStoreFile({
    required this.id,
    required this.object,
    required this.usageBytes,
    required this.createdAt,
    required this.vectorStoreId,
    required this.status,
    this.lastError,
  });

  factory VectorStoreFile.fromJson(Map<String, dynamic> json) {
    return VectorStoreFile(
      id: json['id'] as String,
      object: json['object'] as String,
      usageBytes: json['usage_bytes'] as int,
      createdAt: json['created_at'] as int,
      vectorStoreId: json['vector_store_id'] as String,
      status: json['status'] as String,
      lastError: json['last_error'] != null
          ? LastError.fromJson(json['last_error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class VectorStoreFilesBatch {
  final String id;
  final String object;
  final int createdAt;
  final String vectorStoreId;
  final String status;
  final FileCounts fileCounts;

  VectorStoreFilesBatch({
    required this.id,
    required this.object,
    required this.createdAt,
    required this.vectorStoreId,
    required this.status,
    required this.fileCounts,
  });

  factory VectorStoreFilesBatch.fromJson(Map<String, dynamic> json) {
    return VectorStoreFilesBatch(
      id: json['id'] as String,
      object: json['object'] as String,
      createdAt: json['created_at'] as int,
      vectorStoreId: json['vector_store_id'] as String,
      status: json['status'] as String,
      fileCounts:
          FileCounts.fromJson(json['file_counts'] as Map<String, dynamic>),
    );
  }
}

abstract class Tool {
  final String type;

  Tool(this.type);

  Map<String, dynamic> toJson();

  static Tool fromJson(Map<String, dynamic> json) {
    String type = json['type'];
    switch (type) {
      case 'code_interpreter':
        return CodeInterpreterTool(type);
      case 'file_search':
        return FileSearchTool(type);
      case 'function':
        return FunctionTool.fromJson(json);
      default:
        throw Exception('Unknown tool type: $type');
    }
  }
}

class CodeInterpreterTool extends Tool {
  CodeInterpreterTool(super.type);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
    };
  }
}

class FileSearchTool extends Tool {
  FileSearchTool(super.type);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
    };
  }
}

class FunctionTool extends Tool {
  final FunctionDefinition function;

  FunctionTool({
    required String type,
    required this.function,
  }) : super(type);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'function': function.toJson(),
    };
  }

  factory FunctionTool.fromJson(Map<String, dynamic> json) {
    return FunctionTool(
      type: json['type'],
      function:
          FunctionDefinition.fromJson(json['function'] as Map<String, dynamic>),
    );
  }
}

class FunctionDefinition {
  final String description;
  final String name;
  final Map<String, dynamic> parameters;

  FunctionDefinition({
    required this.description,
    required this.name,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'name': name,
      'parameters': parameters,
    };
  }

  factory FunctionDefinition.fromJson(Map<String, dynamic> json) {
    return FunctionDefinition(
      description: json['description'],
      name: json['name'],
      parameters: json['parameters'],
    );
  }
}

class ToolResources {
  final List<String>? codeInterpreterFileIds;
  final List<String>? fileSearchVectorStoreIds;

  ToolResources({
    this.codeInterpreterFileIds,
    this.fileSearchVectorStoreIds,
  });
  Map<String, dynamic> toJson() {
    return {
      'code_interpreter': {
        'file_ids': codeInterpreterFileIds,
      },
      'file_search': {
        'vector_store_ids': fileSearchVectorStoreIds,
      },
    };
  }

  factory ToolResources.fromJson(Map<String, dynamic> json) {
    List<String>? codeInterpreterFileIds;
    List<String>? fileSearchVectorStoreIds;

    if (json.containsKey('code_interpreter') &&
        json['code_interpreter'] != null) {
      var codeInterpreterData =
          Map<String, dynamic>.from(json['code_interpreter']);
      codeInterpreterFileIds = codeInterpreterData['file_ids'] != null
          ? List<String>.from(codeInterpreterData['file_ids'])
          : null;
    }

    if (json.containsKey('file_search') && json['file_search'] != null) {
      var fileSearchData = Map<String, dynamic>.from(json['file_search']);
      fileSearchVectorStoreIds = fileSearchData['vector_store_ids'] != null
          ? List<String>.from(fileSearchData['vector_store_ids'])
          : null;
    }

    return ToolResources(
      codeInterpreterFileIds: codeInterpreterFileIds,
      fileSearchVectorStoreIds: fileSearchVectorStoreIds,
    );
  }
}

class ResponseFormat {
  final String type;
  final dynamic content;

  ResponseFormat({
    required this.type,
    this.content,
  });
  toJson() {
    return {'type': type, 'content': content};
  }

  factory ResponseFormat.fromJson(dynamic json) {
    // JSON 응답이 문자열일 경우
    if (json is String) {
      return ResponseFormat(type: json);
    }
    // JSON 응답이 객체일 경우
    else if (json is Map<String, dynamic>) {
      return ResponseFormat(
        type: json['type'],
        content: json['content'],
      );
    } else {
      throw Exception('Invalid response_format data');
    }
  }
}

class FileCitation {
  final String text;
  final String fileId;
  final String quote;
  final int startIndex;
  final int endIndex;

  FileCitation({
    required this.text,
    required this.fileId,
    required this.quote,
    required this.startIndex,
    required this.endIndex,
  });

  factory FileCitation.fromJson(Map<String, dynamic> json) {
    return FileCitation(
      text: json['text'] as String,
      fileId: json['file_citation']['file_id'] as String,
      quote: json['file_citation']['quote'] as String,
      startIndex: json['file_citation']['start_index'] as int,
      endIndex: json['file_citation']['end_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'fileId': fileId,
      'quote': quote,
      'start_index': startIndex,
      'end-index': endIndex
    };
  }
}

class FilePath {
  final String text;
  final String fileId;
  final int startIndex;
  final int endIndex;

  FilePath({
    required this.text,
    required this.fileId,
    required this.startIndex,
    required this.endIndex,
  });

  factory FilePath.fromJson(Map<String, dynamic> json) {
    return FilePath(
      text: json['text'] as String,
      fileId: json['file_path']['file_id'] as String,
      startIndex: json['file_path']['start_index'] as int,
      endIndex: json['file_path']['end_index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'fileId': fileId,
      'startIndex': startIndex,
      'endIndex': endIndex
    };
  }
}

class Annotation {
  final String type;
  final FileCitation? fileCitation;
  final FilePath? filePath;

  Annotation({
    required this.type,
    this.fileCitation,
    this.filePath,
  });

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      type: json['type'] as String,
      fileCitation:
          json['type'] == 'file_citation' ? FileCitation.fromJson(json) : null,
      filePath: json['type'] == 'file_path' ? FilePath.fromJson(json) : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {'type': type};
    if (type == 'file_citation' && fileCitation != null) {
      data['file_citation'] = fileCitation!.toJson();
    } else if (type == 'file_path' && filePath != null) {
      data['file_path'] = filePath!.toJson();
    }
    return data;
  }
}

class TextContent extends ContentItem {
  String value;
  List<Annotation>? annotations;

  TextContent({
    required this.value,
    this.annotations,
  });
  toText() {
    return value;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'text',
      'text': {
        'value': value,
        'annotations': annotations?.map((e) => e.toJson()).toList() ?? []
      }
    };
  }

  Map<String, dynamic> toRequestJson() {
    return {'type': 'text', 'text': value};
  }

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(
      value: json['text']['value'] as String,
      annotations: (json['text']['annotations'] as List)
          .map((e) => Annotation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ImageFile extends ContentItem {
  String fileReference;

  ImageFile({required this.fileReference});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image_file',
        'image_file': fileReference,
      };

  factory ImageFile.fromJson(Map<String, dynamic> json) {
    return ImageFile(fileReference: json['image_file']);
  }
}

class ImageUrl extends ContentItem {
  String imageUrl;

  ImageUrl({required this.imageUrl});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image_url',
        'image_url': imageUrl,
      };
  factory ImageUrl.fromJson(Map<String, dynamic> json) {
    return ImageUrl(imageUrl: json['image_url']);
  }
}

enum Role { user, assistant }

abstract class ContentItem {
  Map<String, dynamic> toJson();
  static ContentItem fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextContent.fromJson(json);
      case 'image_file':
        return ImageFile.fromJson(json);
      case 'image_url':
        return ImageUrl.fromJson(json);
      default:
        throw Exception('Unknown ContentItem type');
    }
  }
}

class Attachment {
  final String fileId;
  final List<Tool> tools;

  Attachment({
    required this.fileId,
    required this.tools,
  });
  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'tools': tools.map((tool) => tool.toJson()).toList(),
    };
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      fileId: json['file_id'] as String,
      tools: (json['tools'] as List<dynamic>)
          .map((e) => Tool.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
  Map<String, int> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    };
  }

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      promptTokens: json['prompt_tokens'] as int,
      completionTokens: json['completion_tokens'] as int,
      totalTokens: json['total_tokens'] as int,
    );
  }
}

class RequiredAction {
  final String type;
  final ToolOutput submitToolOutputs;

  RequiredAction({
    required this.type,
    required this.submitToolOutputs,
  });

  factory RequiredAction.fromJson(Map<String, dynamic> json) {
    return RequiredAction(
      type: json['type'] as String,
      submitToolOutputs: ToolOutput.fromJson(
          json['submit_tool_outputs'] as Map<String, dynamic>),
    );
  }
}

class ToolOutput {
  final List<ToolCall> toolCalls;

  ToolOutput({
    required this.toolCalls,
  });

  factory ToolOutput.fromJson(Map<String, dynamic> json) {
    return ToolOutput(
      toolCalls: (json['tool_calls'] as List)
          .map((item) => ToolCall.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ToolCall {
  final String id;
  final String type;
  final FunctionObject function;

  ToolCall({
    required this.id,
    required this.type,
    required this.function,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] as String,
      type: json['type'] as String,
      function:
          FunctionObject.fromJson(json['function'] as Map<String, dynamic>),
    );
  }
}

class FunctionObject {
  final String name;
  final String arguments;

  FunctionObject({
    required this.name,
    required this.arguments,
  });

  factory FunctionObject.fromJson(Map<String, dynamic> json) {
    return FunctionObject(
      name: json['name'] as String,
      arguments: json['arguments'] as String,
    );
  }
}

class LastError {
  final String code;
  final String message;

  LastError({
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message};
  }

  factory LastError.fromJson(Map<String, dynamic> json) {
    return LastError(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

class IncompleteDetails {
  final String reason;

  IncompleteDetails({required this.reason});
  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
    };
  }

  factory IncompleteDetails.fromJson(Map<String, dynamic> json) {
    return IncompleteDetails(
      reason: json['reason'] as String,
    );
  }
}

class TruncationStrategy {
  //'auto' or 'last_messages'
  final String type;
  final int? lastMessages;

  TruncationStrategy({required this.type, this.lastMessages});
  Map<String, dynamic> toJson() {
    return {'type': type, 'lastMessages': lastMessages};
  }

  factory TruncationStrategy.fromJson(Map<String, dynamic> json) {
    return TruncationStrategy(
      type: json['type'] as String,
      lastMessages: json['last_messages'] as int?,
    );
  }
}

class ToolChoice {
  final String type;
  final String? functionName;

  ToolChoice({required this.type, this.functionName});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (functionName != null) 'function': {'name': functionName}
    };
  }

  factory ToolChoice.fromJson(dynamic json) {
    if (json == null) {
      // null 인 경우 'auto'를 기본값으로 설정
      return ToolChoice(type: 'auto');
    } else if (json is String) {
      // 'none', 'auto', 'required' 등의 문자열 처리
      return ToolChoice(type: json);
    } else if (json is Map<String, dynamic>) {
      // 객체 유형의 처리, 함수 이름을 추출
      String type = json['type'];
      String? functionName;
      if (type == 'function' && json.containsKey('function')) {
        functionName = json['function']['name'];
      }
      return ToolChoice(type: type, functionName: functionName);
    } else {
      throw Exception('Invalid JSON type for ToolChoice');
    }
  }
}

class StepDetails {
  final String type;
  final MessageCreation messageCreation;
  final ToolCalls toolCalls;

  StepDetails({
    required this.type,
    required this.messageCreation,
    required this.toolCalls,
  });

  factory StepDetails.fromJson(Map<String, dynamic> json) {
    return StepDetails(
      type: json['type'] as String,
      messageCreation: MessageCreation.fromJson(
          json['message_creation'] as Map<String, dynamic>),
      toolCalls: ToolCalls.fromJson(json['tool_calls'] as Map<String, dynamic>),
    );
  }
}

class MessageCreation {
  final String messageId;

  MessageCreation({required this.messageId});

  factory MessageCreation.fromJson(Map<String, dynamic> json) {
    return MessageCreation(
      messageId: json['message_id'] as String,
    );
  }
}

class ToolCalls {
  final List<ToolCall> calls;

  ToolCalls({required this.calls});

  factory ToolCalls.fromJson(Map<String, dynamic> json) {
    return ToolCalls(
      calls: (json['calls'] as List<dynamic>)
          .map(
              (callJson) => ToolCall.fromJson(callJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExpiresAfter {
  final String anchor;
  final int days;

  ExpiresAfter({
    required this.anchor,
    required this.days,
  });

  factory ExpiresAfter.fromJson(Map<String, dynamic> json) {
    return ExpiresAfter(
      anchor: json['anchor'] as String,
      days: json['days'] as int,
    );
  }
}

class FileCounts {
  final int inProgress;
  final int completed;
  final int failed;
  final int cancelled;
  final int total;

  FileCounts({
    required this.inProgress,
    required this.completed,
    required this.failed,
    required this.cancelled,
    required this.total,
  });

  factory FileCounts.fromJson(Map<String, dynamic> json) {
    return FileCounts(
      inProgress: json['in_progress'] as int,
      completed: json['completed'] as int,
      failed: json['failed'] as int,
      cancelled: json['cancelled'] as int,
      total: json['total'] as int,
    );
  }
}

class AdditionalMessage {
  final Role? role;
  final String content;
  final List<Attachment>? attachments;
  final Map<String, dynamic>? metadata;

  AdditionalMessage(
      {required this.role,
      required this.content,
      this.attachments,
      this.metadata});
  Map<String, dynamic> toJson() {
    return {
      'role': role != null ? role.toString().split('.').last : 'user',
      'content': content,
      'attachments': attachments,
      'metadata': metadata
    };
  }

  factory AdditionalMessage.fromJson(Map<String, dynamic> json) {
    Role role = json['role'] == 'user' ? Role.user : Role.assistant;
    String content = json['content'];
    List<Attachment>? attachments = json['attachments']?.fromJson();
    Map<String, dynamic>? metadata = json['metadata']?.fromJson();

    return AdditionalMessage(
        role: role,
        content: content,
        attachments: attachments,
        metadata: metadata);
  }
}


