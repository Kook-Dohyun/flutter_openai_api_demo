import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:openai/src/services/image_request_object_classes.dart';
import 'dart:convert';
import 'assistant_response_classes.dart';

class OpenAiClient {
  String _apiKey;
  String _baseUrl;
  String _apiVersion;

  OpenAiClient(
      {required String apiKey,
      required String apiVersion,
      required String baseUrl})
      : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _apiVersion = apiVersion;

  void updateApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  void updateApiVersion(String apiVersion) {
    _apiVersion = apiVersion;
  }

  /// GET 요청
  Future<Map<String, dynamic>> _getRequest(
      String endpoint, bool content) async {
    final url = Uri.parse('$_baseUrl/$_apiVersion/$endpoint');
    final response = await http.get(
      url,
      headers: {
        if (content) 'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v2', // Assistants에만 해당.
      },
    );

    String responseBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
    // print(responseBody);
    if (jsonResponse.containsKey('error')) {
      String errorMessage =
          jsonResponse['error']['message'] ?? "알 수 없는 오류가 발생했습니다.";
      throw Exception('API 요청 실패: $errorMessage');
    } else if (response.statusCode != 200) {
      // 에러 발생 시 상태 코드와 응답 본문의 에러 메시지를 포함하여 예외를 던짐
      String errorDetail = jsonResponse.containsKey('error')
          ? jsonResponse['error']['message']
          : "No additional error information provided.";
      throw Exception(
          'Failed to load data: HTTP ${response.statusCode} - $errorDetail');
    }

    return jsonResponse; // 정상적인 경우, 파싱된 JSON 응답을 반환
  }

  /// POST 요청
  Future<Map<String, dynamic>> _postRequest(
      String endpoint, Map<String, dynamic>? data, bool content) async {
    final url = Uri.parse('$_baseUrl/$_apiVersion/$endpoint');
    final response = await http.post(
      url,
      headers: {
        if (content) 'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v2',
      },
      body: json.encode(data),
    );

    String responseBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
    // print(responseBody);
    if (jsonResponse.containsKey('error')) {
      // print("응답 본문: $jsonResponse"); // 응답 본문 로깅
      String errorMessage =
          jsonResponse['error']['message'] ?? "알 수 없는 오류가 발생했습니다.";
      throw Exception('API 요청 실패: $errorMessage');
    } else if (response.statusCode != 200) {
      throw Exception(
          'API 요청 실패, 상태 코드: ${response.statusCode}, 메시지: ${jsonResponse['error']['message']}');
    }

    return jsonResponse;
  }

  /// DELETE 요청
  Future<Map<String, dynamic>> _deleteRequest(String endpoint) async {
    final url = Uri.parse('$_baseUrl/$_apiVersion/$endpoint');
    final response = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
      'OpenAI-Beta': 'assistants=v2'
    });
    String responseBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic> jsonResponse = jsonDecode(responseBody);

    if (jsonResponse.containsKey('error')) {
      String errorMessage =
          jsonResponse['error']['message'] ?? "알 수 없는 오류가 발생했습니다.";
      throw Exception('API 요청 실패: $errorMessage');
    } else if (response.statusCode != 200) {
      throw Exception(
          'API 요청 실패, 상태 코드: ${response.statusCode}, 메시지: ${jsonResponse['error']['message']}');
    }

    return jsonResponse;
  }

  /// Available Models
  Future<List<dynamic>> loadModels() async {
    const endpoint = "models";
    final response = await _getRequest(endpoint, true);
    return response['data'];
  }

  /// Assistans
  // 1.Create an assistant
  Future<bool> createAssistant({
    required String model,
    String? name,
    String? description,
    String? instructions,
    List<Tool>? tools,
    Map<String, dynamic>? toolResources,
    Map<String, dynamic>? metadata,
    num? temperature,
    num? topP,
    ResponseFormat?
        responseFormat, // This can be a String or Map<String, dynamic> based on the input
  }) async {
    const endpoint = 'assistants';

    Map<String, dynamic> requestBody = {
      'model': model,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (instructions != null) 'instructions': instructions,
      if (tools != null) 'tools': tools.map((tool) => tool.toJson()).toList(),
      if (toolResources != null) 'tool_resources': toolResources,
      if (metadata != null) 'metadata': metadata,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (responseFormat != null) 'response_format': responseFormat,
    };
    try {
      await _postRequest(endpoint, requestBody, true);
      return true; // 요청이 성공하면 true 반환
    } catch (e) {
      rethrow;
    }
  }

  /// 2.Delete an assistant
  Future<bool> deleteAssistant(String assistantId) async {
    final endpoint = 'assistants/$assistantId';
    try {
      await _deleteRequest(endpoint);
      return true; // 요청이 성공하면 true 반환
    } catch (e) {
      rethrow;
    }
  }

  /// 3.List assistants
  Future<List<Assistant>> listAssistants({
    int? limit,
    String? order,
    String? after,
    String? before,
  }) async {
    var queryParameters = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      if (order != null) 'order': order,
      if (after != null) 'after': after,
      if (before != null) 'before': before,
    };
    // 쿼리 파라미터를 쿼리 문자열로 변환
    String queryString = Uri(queryParameters: queryParameters).query;
    String endpoint = 'assistants';
    if (queryString.isNotEmpty) {
      endpoint += '?$queryString'; // 쿼리 문자열이 있을 경우 추가
    }
    try {
      final response = await _getRequest(endpoint, true);
      // JSON 배열을 List<Assistant>로 변환
      List<Assistant> assistants = (response['data'] as List)
          .map((item) => Assistant.fromJson(item))
          .toList();
      return assistants;
    } catch (e) {
      rethrow;
    }
  }

  /// 4.Modify an assistant
  Future<bool> modifyAssistant({
    required String assistantId,
    String? model,
    String? name,
    String? description,
    String? instructions,
    List<Tool>? tools,
    Map? toolResources,
    Map<String, dynamic>? metadata,
    num? temperature,
    num? topP,
    ResponseFormat? responseFormat,
  }) async {
    final endpoint = 'assistants/$assistantId';

    Map<String, dynamic> requestBody = {
      if (model != null) 'model': model,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (instructions != null) 'instructions': instructions,
      if (tools != null) 'tools': tools,
      if (toolResources != null) 'tool_resources': toolResources,
      if (metadata != null) 'metadata': metadata,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (responseFormat != null) 'response_format': responseFormat,
    };
    // String prettyPrint =
    //     const JsonEncoder.withIndent('  ').convert(requestBody);
    // print(prettyPrint);
    try {
      await _postRequest(endpoint, requestBody, true);
      return true; // 요청이 성공하면 true 반환
    } catch (e) {
      rethrow;
    }
  }

  /// Threads
  // 1.Create a thread
  Future<Thread> createThread({
    List<Map<String, dynamic>>? messages,
    Map<String, dynamic>? toolResources,
    Map<String, dynamic>? metadata,
  }) async {
    const endpoint = 'threads';

    Map<String, dynamic> requestBody = {
      if (messages != null) 'messages': messages,
      if (toolResources != null) 'tool_resources': toolResources,
      if (metadata != null) 'metadata': metadata,
    };
    try {
      final json = await _postRequest(endpoint, requestBody, true);
      Thread.fromJson(json);
      return Thread.fromJson(json); // 요청이 성공하면 true 반환
    } catch (e) {
      rethrow;
    }
  }

  /// 2.Retrieve a thread
  Future<Thread> retrieveThread({required String threadId}) async {
    final endpoint = 'threads/$threadId';
    try {
      final response = await _getRequest(endpoint, true);

      // JSON 배열을 List<Assistant>로 변환
      Thread threads = Thread.fromJson(response);
      return threads;
    } catch (e) {
      rethrow;
    }
  }

//   // 3.Modify a thread
//   Future<Thread> modifyThread({
//     required String threadId,
//     Map<String, dynamic>? toolResources,
//     Map<String, dynamic>? metadata,
//   }) async {
//
//     final endpoint = 'threads/$threadId';
//     Map<String, dynamic> requestBody = {
//       if (toolResources != null) 'tool_resources': toolResources,
//       if (metadata != null) 'metadata': metadata,
//     };
//     final response = await _postRequest(endpoint, requestBody, true);
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       return Thread.fromJson(json);
//     } else {
//       // 에러 처리
//       throw Exception('Failed to create assistant: ${response.statusCode}');
//     }
//   }

  /// 4,Delete a thread
  Future<bool> deleteThread({required String threadId}) async {
    final endpoint = 'threads/$threadId';

    try {
      await _deleteRequest(endpoint);
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Message
  /// 1.Create a message in a thread
  Future<Message> createMessage({
    required String threadId,
    required ReqMessage req,
  }) async {
    final endpoint = 'threads/$threadId/messages';

    Map<String, dynamic> requestBody = req.toJson();

    try {
      final response = await _postRequest(endpoint, requestBody, true);
      return Message.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 2.List messages in a thread
  Future<List<Message>> listMessages({
    required String threadId,
    int? limit,
    String? order,
    String? after,
    String? before,
    String? runId,
  }) async {
    var queryParameters = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      if (order != null) 'order': order,
      if (after != null) 'after': after,
      if (before != null) 'before': before,
      if (runId != null) 'run_id': runId,
    };
    String queryString = Uri(queryParameters: queryParameters).query;
    String endpoint = 'threads/$threadId/messages';
    if (queryString.isNotEmpty) {
      endpoint += '?$queryString'; // 쿼리 문자열이 있을 경우 추가
    }
    try {
      final response = await _getRequest(endpoint, true);
      // JSON 배열을 List<Assistant>로 변환
      List<Message> messages = (response['data'] as List)
          .map((item) => Message.fromJson(item))
          .toList();
      return messages;
    } catch (e) {
      return [];
    }
  }

  /// 3.Retrieve a specific message from a thread
  Future<Message> retrieveMessage({
    required String threadId,
    required String messageId,
  }) async {
    final endpoint = 'threads/$threadId/messages/$messageId';
    try {
      final response = await _getRequest(endpoint, true);
      Message message = Message.fromJson(response);
      return message;
    } catch (e) {
      rethrow;
    }
  }

//   /// 4.Modify a specific message in a thread
//   Future<Message> modifyMessage({
//     required String threadId,
//     required String messageId,
//     Map<String, dynamic>? metadata,
//   }) async {
//
//     final endpoint = 'threads/$threadId/messages/$messageId';
//     Map<String, dynamic> requestBody = {
//       if (metadata != null) 'metadata': metadata,
//     };
//     final response = await _postRequest(endpoint, requestBody, true);
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       return Message.fromJson(json);
//     } else {
//       // 에러 처리
//       throw Exception('Failed to create assistant: ${response.statusCode}');
//     }
//   }

  /// 4,Delete a thread
  Future<bool> deleteMessage(
      {required String threadId, required String msgId}) async {
    final endpoint = 'threads/$threadId/messages/$msgId';

    try {
      await _deleteRequest(endpoint);
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Runs
  /// 1.Create run
  Future<Run> createRun({
    required String threadId,
    required String assistantId,
    String? model,
    String? instructions,
    String? additionalInstructions,
    List<AdditionalMessage>? additionalMessages,
    List<Tool>? tools,
    Map<String, dynamic>? metadata,
    num? temperature,
    num? topP,
    bool? stream,
    int? maxPromptTokens,
    int? maxCompletionTokens,
    TruncationStrategy? truncationStrategy,
    // ToolChoice? toolChoice,
    ResponseFormat? responseFormat,
  }) async {
    final endpoint = 'threads/$threadId/runs';

    Map<String, dynamic> requestBody = {
      'assistant_id': assistantId,
      if (model != null) 'model': model,
      if (instructions != null) 'instructions': instructions,
      if (additionalInstructions != null)
        'additional_instructions': additionalInstructions,
      if (additionalMessages != null)
        'additional_messages':
            additionalMessages.map((e) => e.toJson()).toList(),
      if (tools != null) 'tools': tools.map((tool) => tool.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (stream != null) 'stream': stream,
      if (maxPromptTokens != null) 'max_prompt_tokens': maxPromptTokens,
      if (maxCompletionTokens != null)
        'max_completion_tokens': maxCompletionTokens,
      if (truncationStrategy != null)
        'truncation_strategy': truncationStrategy.toJson(),
      // if (toolChoice != null) 'tool_choice': toolChoice.toJson(),
      if (responseFormat != null) 'response_format': responseFormat.toJson(),
    };
    try {
      final response = await _postRequest(endpoint, requestBody, true);
      return Run.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  ///1-1.Create Run stream
  Stream<Map<String, dynamic>> createRunAndListenToEvents({
    required String threadId,
    required String assistantId,
    String? model,
    String? instructions,
    String? additionalInstructions,
    List<AdditionalMessage>? additionalMessages,
    List<Tool>? tools,
    Map<String, dynamic>? metadata,
    num? temperature,
    num? topP,
    bool stream = true,
    int? maxPromptTokens,
    int? maxCompletionTokens,
    TruncationStrategy? truncationStrategy,
    // ToolChoice? toolChoice,
    ResponseFormat? responseFormat,
  }) async* {
    final endpoint = '$_baseUrl/$_apiVersion/threads/$threadId/runs';
    final url = Uri.parse(endpoint);

    Map<String, dynamic> requestBody = {
      'assistant_id': assistantId,
      if (model != null) 'model': model,
      if (instructions != null) 'instructions': instructions,
      if (additionalInstructions != null)
        'additional_instructions': additionalInstructions,
      if (additionalMessages != null)
        'additional_messages':
            additionalMessages.map((e) => e.toJson()).toList(),
      if (tools != null) 'tools': tools.map((tool) => tool.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      'stream': stream,
      if (maxPromptTokens != null) 'max_prompt_tokens': maxPromptTokens,
      if (maxCompletionTokens != null)
        'max_completion_tokens': maxCompletionTokens,
      if (truncationStrategy != null)
        'truncation_strategy': truncationStrategy.toJson(),
      // if (toolChoice != null) 'tool_choice': toolChoice.toJson(),
      if (responseFormat != null) 'response_format': responseFormat.toJson(),
    };

    var request = http.Request('POST', url)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'OpenAI-Beta': 'assistants=v2',
      })
      ..body = json.encode(requestBody);

    var client = http.Client();
    try {
      var streamedResponse = await client.send(request);
      String currentEvent = "";
      await for (var line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
          continue;
        } else if (line.startsWith('data:')) {
          var dataContent = line.substring(5).trim();
          try {
            Map<String, dynamic> dataMap = {};
            if (currentEvent != "done") {
              dataMap = json.decode(dataContent);
            }
            yield {'event': currentEvent, 'data': dataMap};
          } catch (e) {
            print('Error parsing JSON data: $e');
          }
        }
      }
    } finally {
      client.close();
    }
  }

//   /// 2.Create thread and run
//   Future<Run> createThreadAndRun({
//     required String assistantId,
//     List<Map<String, dynamic>>? messages,
//     String? model,
//     String? instructions,
//     String? additionalInstructions,
//     List<Map<String, dynamic>>? additionalMessages,
//     List<Tool>? tools,
//     ToolResources? toolResources,
//     Map<String, dynamic>? metadata,
//     num? temperature,
//     num? topP,
//     bool? stream,
//     int? maxPromptTokens,
//     int? maxCompletionTokens,
//     TruncationStrategy? truncationStrategy,
//     String? toolChoice,
//     ResponseFormat? responseFormat,
//   }) async {
//
//     const endpoint = 'threads/runs';

//     Map<String, dynamic> thread = {};
//     if (messages != null) thread['messages'] = messages;

//     Map<String, dynamic> requestBody = {
//       'assistant_id': assistantId,
//       if (model != null) 'model': model,
//       if (instructions != null) 'instructions': instructions,
//       if (additionalInstructions != null)
//         'additional_instructions': additionalInstructions,
//       if (additionalMessages != null)
//         'additional_messages': additionalMessages.map((m) => m).toList(),
//       if (tools != null) 'tools': tools,
//       if (toolResources != null) 'tool_resources': toolResources.toJson(),
//       if (metadata != null) 'metadata': metadata,
//       if (temperature != null) 'temperature': temperature,
//       if (topP != null) 'top_p': topP,
//       if (stream != null) 'stream': stream,
//       if (maxPromptTokens != null) 'max_prompt_tokens': maxPromptTokens,
//       if (maxCompletionTokens != null)
//         'max_completion_tokens': maxCompletionTokens,
//       if (truncationStrategy != null)
//         'truncation_strategy': truncationStrategy.toJson(),
//       if (toolChoice != null) 'tool_choice': toolChoice,
//       if (responseFormat != null) 'response_format': responseFormat,
//     };

//     // Only add 'thread' if it's not empty.
//     if (thread.isNotEmpty) requestBody['thread'] = thread;

//     final response = await _postRequest(endpoint, requestBody, true);
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       return Run.fromJson(json);
//     } else {
//       throw Exception('Thread and run creation failed: ${response.statusCode}');
//     }
//   }

//   // 3.List runs
//   Future<List<Run>> listThreadRuns({
//     required String threadId,
//     int? limit,
//     String? order,
//     String? after,
//     String? before,
//   }) async {
//
//     final endpoint = 'threads/$threadId/runs';

//     Map<String, String> queryParams = {};
//     if (limit != null) queryParams['limit'] = limit.toString();
//     if (order != null) queryParams['order'] = order;
//     if (after != null) queryParams['after'] = after;
//     if (before != null) queryParams['before'] = before;

//     final response = await _getRequest(endpoint, true);
//     List<Run> runs =
//         (response['data'] as List).map((item) => Run.fromJson(item)).toList();
//     return runs;
//   }

// // Helper function to encode the query parameters
//   String _encodeQueryParams(Map<String, String> params) {
//     if (params.isEmpty) {
//       return '';
//     }
//     return '?${params.entries.map((p) => '${Uri.encodeComponent(p.key)}=${Uri.encodeComponent(p.value)}').join('&')}';
//   }

  /// 4.Retrieve run
  Future<Run> retrieveRun({
    required String threadId,
    required String runId,
  }) async {
    final endpoint = 'threads/$threadId/runs/$runId';
    try {
      final response = await _getRequest(endpoint, true);
      return Run.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

//   /// 5.Modify run
//   Future<Run> modifyRun({
//     required String threadId,
//     required String runId,
//     Map<String, dynamic>? metadata,
//   }) async {
//
//     final endpoint = 'threads/$threadId/runs/$runId';

//     Map<String, dynamic> requestBody = {};
//     if (metadata != null) {
//       requestBody['metadata'] = metadata;
//     }

//     final response = await _postRequest(endpoint, requestBody, true);
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       return Run.fromJson(json); // Assumes json structure directly maps to Run
//     } else {
//       throw Exception(
//           'Failed to modify run for thread $threadId with run ID $runId: ${response.statusCode}');
//     }
//   }

//   /// 6.Submit tool outputs to run
//   Future<Run> submitToolOutputs({
//     required String threadId,
//     required String runId,
//     required List<Map<String, dynamic>> toolOutputs,
//     bool? stream,
//   }) async {
//
//     final endpoint = 'threads/$threadId/runs/$runId/submit_tool_outputs';

//     Map<String, dynamic> requestBody = {
//       'tool_outputs': toolOutputs,
//       if (stream != null) 'stream': stream,
//     };

//     final response = await _postRequest(endpoint, requestBody, true);
//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body);
//       return Run.fromJson(json); // Assumes json structure directly maps to Run
//     } else {
//       throw Exception(
//           'Failed to submit tool outputs for thread $threadId with run ID $runId: ${response.statusCode}');
//     }
//   }

  /// 7.Cancel a run
  Future<void> cancleRun(
      {required String threadId, required String runId}) async {
    final endpoint = 'threads/$threadId/runs/$runId/cancel';

    try {
      print('cancel run');
      await _postRequest(endpoint, {}, true);
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  ///Run Steps
  ///1.List run steps
  Future<void> listRunSteps(
      {required String threadId, required String runId}) async {
    final endpoint = 'threads/$threadId/runs/$runId/steps';

    final response = await _getRequest(endpoint, true);

    List<dynamic> dataList = response['data'];
    for (var map in dataList) {
      map.forEach((key, value) {
        // print('  $key: $value');
      });
    }
  }

//   //Vector Stores

//   //Vector Stores Files

//   //Vector Stores File Batces

//   //Streaming

// class FirebaseFunctionsClient {
//   final String baseUrl =
//       "https://asia-northeast3-openai-6eefd.cloudfunctions.net"; // Firebase Function이 호스팅된 URL
//   final String userId; // 사용자 ID
//   final String assistantId; // 어시스턴트 ID
//   final String threadId; // 쓰레드 ID
//   final String apiKey; // API 키

//   FirebaseFunctionsClient({
//     required this.userId,
//     required this.assistantId,
//     required this.threadId,
//     required this.apiKey,
//   });

//   /// Firebase Function을 호출하여 OpenAI의 런 스트리밍을 시작합니다.
//   Future<void> createRunStreaming() async {
//     final url =
//         Uri.parse('$baseUrl/streamOpenAIResponse').replace(queryParameters: {
//       'userId': userId,
//       'assistantId': assistantId,
//       'threadId': threadId,
//       'apiKey': apiKey
//     });

//     try {
//       final response =
//           await http.get(url, headers: {'Content-Type': 'application/json'});

//       if (response.statusCode == 200) {
//         print('Streaming started successfully');
//         // 여기서 응답을 스트리밍으로 처리할 로직을 추가할 수 있습니다.
//       } else {
//         print('Failed to start streaming: ${response.body}');
//       }
//     } catch (e) {
//       print('Exception when calling Firebase Function: $e');
//       rethrow;
//     }
//   }
// }
  Future<void> saveNetworkImage(String url) async {
    var response = await Dio().get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    await ImageGallerySaver.saveImage(
      Uint8List.fromList(response.data),
      quality: 60,
      name: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> saveBase64Image(String base64Data) async {
    Uint8List imageData = base64Decode(base64Data);
    await ImageGallerySaver.saveImage(
      imageData,
      quality: 60,
      name: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Images
  ///1. Create Image
  Future<Map<String, dynamic>> createImage(
      {required CreateImageRequest createImageRequest}) async {
    const endpoint = 'images/generations';
    Map<String, dynamic> requestBody = createImageRequest.toJson();
    try {
      print('run');
      final json = await _postRequest(endpoint, requestBody, true);
      print(json);
      return json;
    } catch (e) {
      rethrow;
    }
  }
}
