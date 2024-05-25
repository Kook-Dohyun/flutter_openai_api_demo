import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:openai/src/services/openai_client.dart';
import 'package:openai/src/services/assistant_response_classes.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

import 'document_editor_page.dart';

class ModifyOrCreateAssistantPage extends StatefulWidget {
  final String action;
  final Assistant? assistant;

  const ModifyOrCreateAssistantPage(
      {super.key, required this.action, this.assistant});

  @override
  State<ModifyOrCreateAssistantPage> createState() =>
      _ModifyOrCreateAssistantPageState();
}

class _ModifyOrCreateAssistantPageState
    extends State<ModifyOrCreateAssistantPage> {
  final _formKey = GlobalKey<FormState>();
  late String _assistantId;
  late String _name = '';
  late String _description = '';
  late String _instructions;
  late String _selectedModel = '';
  late num _topP = 1;
  late num _temperature = 1;
  late List<Tool> _tools;
  late bool _isCodeInterpreterEnabled = false;
  late bool _isFileSearchEnabled = false;
  final List _models = [];
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    setState(() {
      if (widget.assistant != null) {
        _assistantId = widget.assistant!.id;
        if (widget.assistant!.name! != '') _name = widget.assistant!.name!;
        if (widget.assistant!.description != null) {
          _description = widget.assistant!.description!;
        }
        if (widget.assistant!.instructions! != '') {
          controller.text = widget.assistant!.instructions!;
        }
        _topP = widget.assistant!.topP!;
        _temperature = widget.assistant!.temperature!;
        _tools = widget.assistant!.tools;
        _selectedModel = widget.assistant!.model;
        _isCodeInterpreterEnabled = widget.assistant!.tools
            .any((tool) => tool.type == 'code_interpreter');
        _isFileSearchEnabled =
            widget.assistant!.tools.any((tool) => tool.type == 'file_search');
      }
    });
    _loadModels();
  }

  void _loadModels() async {
    final models =
        await context.read<SettingsController>().openAiClient.loadModels();
    if (models.isNotEmpty) {
      for (final model in models) {
        _models.add(model);

        // if (model['id']!.contains('gpt')) {
        //   _models.add(model);
        // }
      }
      if (widget.assistant == null) {
        _selectedModel = _models[0]['id']!;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _submitForm(String action) async {
    OpenAiClient openai = context.read<SettingsController>().openAiClient;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _tools = []; // Reset tools
      if (_isCodeInterpreterEnabled) {
        _tools.add(CodeInterpreterTool('code_interpreter'));
      }
      if (_isFileSearchEnabled) {
        _tools.add(FileSearchTool('file_search'));
      }
      try {
        bool success;
        if (widget.assistant != null && action == '수정') {
          success = await openai.modifyAssistant(
              assistantId: _assistantId,
              name: _name,
              description: _description,
              model: _selectedModel,
              instructions: _instructions,
              topP: _topP,
              temperature: _temperature,
              tools: _tools);
        } else if (action == '추가') {
          success = await openai.createAssistant(
              name: _name,
              description: _description,
              model: _selectedModel,
              instructions: _instructions,
              topP: _topP,
              temperature: _temperature,
              tools: _tools);
        } else {
          success = await openai.createAssistant(
              name: 'Copy $_name',
              description: _description,
              model: _selectedModel,
              instructions: _instructions,
              topP: _topP,
              temperature: _temperature,
              tools: _tools);
        }

        if (success) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('어시스턴트가 성공적으로 $action되었습니다.')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _instructions = controller.text;
    return Scaffold(
      appBar: AppBar(
        title: Text("어시스턴트 ${widget.action}하기"),
        actions: [
          widget.assistant == null
              ? const SizedBox()
              : IconButton(
                  onPressed: () async {
                    _submitForm('복제');
                  },
                  tooltip: '복제하기',
                  icon: const Icon(FontAwesomeIcons.solidClone)),
          IconButton(
              onPressed: () async {
                _submitForm(widget.action);
              },
              tooltip: '저장하기',
              icon: const Icon(Icons.save))
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  initialValue: _name.isNotEmpty ? _name : '',
                  decoration: const InputDecoration(
                      labelText: '이름', alignLabelWithHint: true),
                  maxLength: 256,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '어시스턴트 이름을 입력해주세요.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value!;
                  },
                ),

                TextFormField(
                  initialValue: _description.isNotEmpty ? _description : '',
                  decoration: const InputDecoration(
                      labelText: '설명', alignLabelWithHint: true),
                  maxLines: 5,
                  validator: (value) {
                    return null;
                  },
                  onSaved: (value) {
                    _description = value!;
                  },
                ),
                const SizedBox(height: 16), // 여백 추가

                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DocumentEditorPage(controller: controller),
                      ),
                    );
                    setState(() {
                      _instructions;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Stack(children: [
                      Text(
                        _instructions.isEmpty ? '지시사항을 입력하세요' : _instructions,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Positioned(
                          top: 0,
                          right: 0,
                          child: FaIcon(
                            FontAwesomeIcons.upRightAndDownLeftFromCenter,
                            size: 13,
                          ))
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  items: _models.map((model) {
                    return DropdownMenuItem<String>(
                      value: model['id'],
                      child: Text(model['id'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedModel = newValue;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: '모델 선택',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TopP: $_topP'),
                      Slider(
                          value: _topP.toDouble(),
                          max: 1,
                          divisions: 100,
                          onChanged: (value) {
                            setState(() {
                              _topP = value;
                            });
                          }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temperature: $_temperature'),
                      Slider(
                          value: _temperature.toDouble(),
                          max: 2,
                          divisions: 200,
                          onChanged: (value) {
                            setState(() {
                              _temperature = value;
                            });
                          }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(children: [
                    SwitchListTile(
                      title: const Text('Enable Code Interpreter'),
                      value: _isCodeInterpreterEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _isCodeInterpreterEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Enable File Search'),
                      value: _isFileSearchEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _isFileSearchEnabled = value;
                        });
                      },
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
