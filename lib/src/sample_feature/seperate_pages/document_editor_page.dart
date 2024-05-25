import 'package:flutter/material.dart'; 

class DocumentEditorPage extends StatefulWidget {
  final TextEditingController controller;

  const DocumentEditorPage({super.key, required this.controller});

  @override
  State<DocumentEditorPage> createState() => _DocumentEditorPageState();
}

class _DocumentEditorPageState extends State<DocumentEditorPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  // 상태 업데이트 함수
  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearText() {
    // 텍스트 필드를 비우는 함수
    setState(() {
      widget.controller.text = "";
      _update(); // 텍스트를 지우고 저장 로직 호출
    });
  }

  void _wrapTextWith(String prefix, String suffix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return; // 유효한 선택이 아니면 종료

    final beforeText = text.substring(0, selection.start);
    final selectedText = text.substring(selection.start, selection.end);
    final afterText = text.substring(selection.end, text.length);

    // 선택된 텍스트를 감싸고 전체 텍스트를 업데이트
    widget.controller.text =
        beforeText + prefix + selectedText + suffix + afterText;

    // 커서 위치를 감싼 텍스트 끝으로 이동
    final newSelectionEnd =
        selection.start + prefix.length + selectedText.length + suffix.length;
    widget.controller.selection =
        TextSelection.fromPosition(TextPosition(offset: newSelectionEnd));
  }

  double _scaleFactor = 16.0;
  double _baseScaleFactor = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("지시사항 편집기"),
        actions: [
          IconButton(
            icon: widget.controller.text.isNotEmpty
                ? const Icon(Icons.delete_rounded)
                : const Icon(Icons.delete_outline_rounded),
            disabledColor: Colors.grey[700],
            onPressed: widget.controller.text.isNotEmpty
                ? () {
                    setState(() {
                      _clearText();
                    });
                  }
                : null,
          ),
        ],
      ),
      body: GestureDetector(
        onScaleStart: (details) {
          _baseScaleFactor = _scaleFactor;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scaleFactor = _baseScaleFactor * details.scale;
          });
        },
        child: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                    style: TextStyle(fontSize: _scaleFactor),
                    expands: true,
                    controller: widget.controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                        hintText: '지시사항을 입력하세요', isCollapsed: true)),
              ),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.start,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () => _wrapTextWith("[", "]"),
                  child: const Icon(Icons.data_array_outlined),
                ),
                ElevatedButton(
                  onPressed: () => _wrapTextWith("{", "}"),
                  child: const Icon(Icons.data_object_outlined),
                ),
                ElevatedButton(
                  onPressed: () => _wrapTextWith("<", ">"),
                  child: const Icon(Icons.code_rounded),
                ),
                ElevatedButton(
                  onPressed: () => _wrapTextWith("*", "*"),
                  child: const Text(
                    '* *',
                    style: TextStyle(fontSize: 25),
                  ),
                ),
                const ElevatedButton(
                  onPressed: null,
                  child: Icon(Icons.copy_all_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
