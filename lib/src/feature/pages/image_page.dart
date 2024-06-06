//             'https://c3.klipartz.com/pngpicture/98/988/sticker-png-jennie-blackpink.png'
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:openai/src/services/image_request_object_classes.dart';
import 'package:openai/src/services/openai_client.dart';
import 'package:openai/src/settings/settings_controller.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

class ImagePage extends StatefulWidget {
  final String title;
  const ImagePage({super.key, required this.title});

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> with WidgetsBindingObserver {
  late final Box<dynamic> box;
  late final Box promptBox;
  late final OpenAiClient openai;
  late TextEditingController textController;
  final FocusNode _focusNode = FocusNode();
  List<SavedImageData> savedImageDataList = [];
  Map<int, Uint8List?> cachedImageData = {};
  bool rateLimitExceeded = false;
  String? errorMessage;
  bool _onGen = false;
  bool loading = true;
  bool _showController = false;

  Model selectedModel = Model.dalle3;
  ImageSize selectedSize = ImageSize.large1024x1024;
  Quality selectedQuality = Quality.standard;
  Style selectedStyle = Style.vivid;
  int selectedN = 1;
  ImgResponseFormat selectedResponseFormat = ImgResponseFormat.b64Json;
  late String masterPrompt;
  bool applyMasterPrompt = false;

  @override
  void initState() {
    super.initState();
    final settingsController =
        Provider.of<SettingsController>(context, listen: false);
    openai = settingsController.openAiClient;
    initBox();
    textController = TextEditingController();
    textController.addListener(_checkForSlash);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  double _previousBottomInset = 0;
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bottomInset = View.of(context).viewInsets.bottom;
        if (_previousBottomInset > 0 && bottomInset == 0) {
          _focusNode.unfocus(); // 키보드가 내려갔을 때 포커스 해제
        }
        _previousBottomInset = bottomInset;
      }
    });
  }

  void _checkForSlash() {
    if (textController.text.startsWith('@')) {
      setState(() {
        applyMasterPrompt = true;
      });
    } else {
      setState(() {
        applyMasterPrompt = false;
      });
    }
  }

  Future<void> initBox() async {
    box = await Hive.openBox('Images');
    promptBox = await Hive.openBox('image_prompts');
    masterPrompt = promptBox.get('master_prompt',
        defaultValue:
            "I NEED to test how the tool works with extremely simple prompts. DO NOT add any detail, just use it AS-IS: ");

    await _loadImageResponses();
  }

  Future<void> _loadImageResponses() async {
    await getImageResponsesFromHive();
    _cacheImageData();
  }

  Future<void> getImageResponsesFromHive() async {
    final box = await Hive.openBox('Images');

    for (var value in box.values) {
      if (value is Map) {
        var castedMap =
            Map<String, dynamic>.from(value.cast<dynamic, dynamic>());
        savedImageDataList.add(SavedImageData.fromJson(castedMap));
      }
    }
  }

  void _cacheImageData() {
    for (int i = 0; i < savedImageDataList.length; i++) {
      for (var imageData in savedImageDataList[i].imageResponse.data) {
        if (imageData.base64 != null) {
          cachedImageData[i] = base64Decode(imageData.base64!);
        }
      }
    }
    setState(() {
      cachedImageData;
      loading = false;
    });
  }

  Future<void> updateImageStatus(
      {required int index, required SavedImageData savedData}) async {
    if (index >= 0 && index < savedImageDataList.length) {
      await box.putAt(index, savedData.toJson());
    }
  }

  Future<void> _createImage() async {
    try {
      HapticFeedback.heavyImpact();
      setState(() {
        rateLimitExceeded = false;
        errorMessage = null;
        _onGen = true;
      });
      String prompt = (applyMasterPrompt ? masterPrompt : '') +
          textController.text.substring(1);
      CreateImageRequest request = selectedModel == Model.dalle2
          ? CreateImageRequest.dalle2(
              prompt: applyMasterPrompt ? prompt : textController.text,
              n: selectedN,
              size: selectedSize,
              responseFormat: selectedResponseFormat,
            )
          : CreateImageRequest.dalle3(
              prompt: applyMasterPrompt ? prompt : textController.text,
              size: selectedSize,
              style: selectedStyle,
              responseFormat: selectedResponseFormat,
            );

      var imageResponseMap =
          await openai.createImage(createImageRequest: request);
      ImageResponse imageResponse = ImageResponse.fromJson(imageResponseMap);

      SavedImageData savedImageData =
          SavedImageData(prompt: prompt, imageResponse: imageResponse);

      await box.add(savedImageData.toJson());

      if (mounted) {
        setState(() {
          _onGen = false;
          savedImageDataList.add(savedImageData);
          int index = savedImageDataList.length - 1;
          for (var imageData in imageResponse.data) {
            if (imageData.base64 != null) {
              cachedImageData[index] = base64Decode(imageData.base64!);
            }
          }
        });
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _onGen = false;
          errorMessage = 'Failed to create image: $e';
        });
      }
    }
  }

  Future<void> deleteImage({required int index}) async {
    if (index >= 0 && index < savedImageDataList.length) {
      savedImageDataList.removeAt(index);
      _cacheImageData();
      await box.deleteAt(index);
    }
  }

  Future<void> convertAndSaveImageUrlToBase64(
      {required int index,
      required SavedImageData savedImageData,
      required String imageUrl}) async {
    try {
      var response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      Uint8List imageBytes = Uint8List.fromList(response.data);
      String base64String = base64Encode(imageBytes);

      // 기존 SavedImageData 객체 업데이트
      ImageData updatedImageData = ImageData(
        revisedPrompt: savedImageData.imageResponse.data.first.revisedPrompt,
        url: null,
        base64: base64String,
      );

      ImageResponse updatedImageResponse = ImageResponse(
        created: savedImageData.imageResponse.created,
        data: [updatedImageData],
      );

      SavedImageData updatedSavedImageData = SavedImageData(
        prompt: savedImageData.prompt,
        imageResponse: updatedImageResponse,
        isLiked: savedImageData.isLiked,
      );

      await updateImageStatus(index: index, savedData: updatedSavedImageData);
      setState(() {
        savedImageDataList[index] = updatedSavedImageData;
        cachedImageData[index] = imageBytes;
      });
    } catch (e) {
      throw Exception('Failed to convert and save image URL to base64: $e');
    }
  }

  String timeInterpreter(int time, {String format = 'yy/MM/dd HH:mm'}) {
    DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    String timestamp = DateFormat(format).format(createdAt);
    return timestamp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: '/images',
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              final likedImages =
                  savedImageDataList.where((image) => image.isLiked).toList();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LikedImagesPage(
                      likedImages: likedImages,
                      updateImageStatus: updateImageStatus),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(savedImageDataList.length.toString()),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        reverse: true,
                        itemCount: savedImageDataList.length,
                        itemBuilder: (context, ogIndex) {
                          int index = savedImageDataList.length - 1 - ogIndex;
                          SavedImageData savedData = savedImageDataList[index];
                          ImageResponse response = savedData.imageResponse;
                          return Column(children: <Widget>[
                            ...response.data.map((ImageData imageData) {
                              Uint8List? bytes = cachedImageData[index] ??
                                  (imageData.base64 != null
                                      ? base64Decode(imageData.base64!)
                                      : null);

                              String imageUrl = imageData.url ?? '';
                              return Column(
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    Stack(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ImageViewPage(
                                                  imageUrl: imageUrl,
                                                  indexString: index.toString(),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                              tag: imageUrl + index.toString(),
                                              child: Image.network(imageUrl)),
                                        ),
                                        IconButton(
                                            onPressed: () async {
                                              convertAndSaveImageUrlToBase64(
                                                  index: index,
                                                  imageUrl: imageUrl,
                                                  savedImageData: savedData);
                                            },
                                            iconSize: 40,
                                            icon: const Icon(Icons.sync)),
                                      ],
                                    ),
                                  if (bytes != null)
                                    Stack(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ImageViewPage(
                                                        bytes: bytes,
                                                        indexString:
                                                            index.toString(),
                                                      )),
                                            );
                                          },
                                          child: Hero(
                                              tag: bytes,
                                              child: Image.memory(bytes)),
                                        ),
                                      ],
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (bytes != null) const Text('Base64'),
                                        if (imageUrl.isNotEmpty)
                                          const Text('URL'),
                                        Text(
                                            ' • ${timeInterpreter(response.created, format: 'yy-MM-dd•HH:mm:ss')} '),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                      onPressed: () {
                                        bool contained = savedData.prompt
                                            .contains(masterPrompt);
                                        String text = savedData.prompt;
                                        if (contained) {
                                          setState(() {
                                            applyMasterPrompt = true;
                                            text = text.replaceFirst(
                                                masterPrompt, '');
                                          });
                                        }
                                        textController.text = text;
                                      },
                                      onLongPress: () {
                                        Clipboard.setData(ClipboardData(
                                            text: savedData.prompt));
                                      },
                                      child: Text(savedData.prompt)),
                                  TextButton(
                                      onPressed: () {
                                        textController.text =
                                            imageData.revisedPrompt!;
                                      },
                                      onLongPress: () {
                                        Clipboard.setData(ClipboardData(
                                            text:
                                                imageData.revisedPrompt ?? ''));
                                      },
                                      child:
                                          Text(imageData.revisedPrompt ?? '')),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          iconSize: 30,
                                          icon: const Icon(
                                              Icons.download_rounded),
                                          onPressed: () async {
                                            if (imageData.base64 != null) {
                                              await openai.saveBase64Image(
                                                  imageData.base64!);
                                            }
                                            if (imageUrl.isNotEmpty) {
                                              await openai
                                                  .saveNetworkImage(imageUrl);
                                            }
                                            WidgetsBinding.instance
                                                .addPostFrameCallback(
                                                    (timeStamp) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text('Image saved '),
                                              ));
                                            });
                                          },
                                        ),
                                        IconButton(
                                          iconSize: 30,
                                          icon: Icon(
                                            savedData.isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: savedData.isLiked
                                                ? Colors.red
                                                : null,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              savedData.isLiked =
                                                  !savedData.isLiked;
                                              updateImageStatus(
                                                  index: index,
                                                  savedData:
                                                      savedData); // 업데이트된 상태를 저장
                                            });
                                          },
                                        ),
                                        IconButton(
                                          iconSize: 30,
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            await deleteImage(index: index);
                                          },
                                        ),
                                      ]),
                                ],
                              );
                            }),
                          ]);
                        },
                      )),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showController = !_showController;
                          });
                        },
                        icon: _showController
                            ? const Icon(Icons.close)
                            : const Icon(Icons.tune_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: textController,
                          maxLines: 10,
                          minLines: 1,
                          style: Theme.of(context).textTheme.labelLarge,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              onPressed: _onGen ? null : _createImage,
                              icon: _onGen
                                  ? const Icon(Icons.radio_button_on_rounded)
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
                                          end: const Offset(0.9, 0.9))
                                  : textController.text.isEmpty
                                      ? const Icon(Icons.circle)
                                      : const Icon(
                                          Icons.arrow_circle_up_rounded),
                              iconSize: 35,
                            ),
                            hintText: 'Prompt',
                            hintStyle: TextStyle(
                              color: rateLimitExceeded
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color,
                            ),
                            filled: true,
                            fillColor: applyMasterPrompt
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.onSecondary,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(27)),
                            ),
                          ),
                        ),
                      )
                    ]),
                  ),
                  if (_showController)
                    Theme(
                      data: Theme.of(context),
                      child: SizedBox(
                        height: 150,
                        child: GridView(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 18,
                                  mainAxisExtent: 50),
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<Model>(
                                value: selectedModel,
                                onChanged: (Model? newValue) {
                                  setState(() {
                                    selectedModel = newValue!;
                                    selectedN =
                                        1; // Reset n to default when model changes
                                  });
                                },
                                items: Model.values.map((Model model) {
                                  return DropdownMenuItem<Model>(
                                    value: model,
                                    child:
                                        Text(model.toString().split('.').last),
                                  );
                                }).toList(),
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<ImgResponseFormat>(
                                value: selectedResponseFormat,
                                onChanged: (ImgResponseFormat? newValue) {
                                  setState(() {
                                    selectedResponseFormat = newValue!;
                                  });
                                },
                                items: ImgResponseFormat.values
                                    .map((ImgResponseFormat format) {
                                  return DropdownMenuItem<ImgResponseFormat>(
                                    value: format,
                                    child:
                                        Text(format.toString().split('.').last),
                                  );
                                }).toList(),
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<ImageSize>(
                                value: selectedSize,
                                onChanged: (ImageSize? newValue) {
                                  setState(() {
                                    selectedSize = newValue!;
                                  });
                                },
                                items: selectedModel == Model.dalle2
                                    ? ImageSize.values
                                        .where((size) =>
                                            size == ImageSize.small256x256 ||
                                            size == ImageSize.medium512x512 ||
                                            size == ImageSize.large1024x1024)
                                        .map((ImageSize size) {
                                        return DropdownMenuItem<ImageSize>(
                                          value: size,
                                          child: Text(_sizeToString(size)),
                                        );
                                      }).toList()
                                    : ImageSize.values
                                        .where((size) =>
                                            size == ImageSize.large1024x1024 ||
                                            size == ImageSize.wide1792x1024 ||
                                            size == ImageSize.tall1024x1792)
                                        .map((ImageSize size) {
                                        return DropdownMenuItem<ImageSize>(
                                          value: size,
                                          child: Text(_sizeToString(size)),
                                        );
                                      }).toList(),
                              ),
                            ),
                            if (selectedModel == Model.dalle2)
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  const Text('N :'),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: selectedN,
                                      onChanged: (int? newValue) {
                                        setState(() {
                                          selectedN = newValue!;
                                        });
                                      },
                                      items: [1, 2, 3, 4].map((int value) {
                                        return DropdownMenuItem<int>(
                                          value: value,
                                          child: Text(value.toString()),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            if (selectedModel == Model.dalle3) ...[
                              DropdownButtonHideUnderline(
                                child: DropdownButton<Quality>(
                                  value: selectedQuality,
                                  onChanged: (Quality? newValue) {
                                    setState(() {
                                      selectedQuality = newValue!;
                                    });
                                  },
                                  items: Quality.values.map((Quality quality) {
                                    return DropdownMenuItem<Quality>(
                                      value: quality,
                                      child: Text(
                                          quality.toString().split('.').last),
                                    );
                                  }).toList(),
                                ),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<Style>(
                                  value: selectedStyle,
                                  onChanged: (Style? newValue) {
                                    setState(() {
                                      selectedStyle = newValue!;
                                    });
                                  },
                                  items: Style.values.map((Style style) {
                                    return DropdownMenuItem<Style>(
                                      value: style,
                                      child: Text(
                                          style.toString().split('.').last),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ]
                          ],
                        ).animate().fadeIn(curve: Curves.easeIn),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sizeToString(ImageSize size) {
    switch (size) {
      case ImageSize.small256x256:
        return '256x256';
      case ImageSize.medium512x512:
        return '512x512';
      case ImageSize.large1024x1024:
        return '1024x1024';
      case ImageSize.wide1792x1024:
        return '1792x1024';
      case ImageSize.tall1024x1792:
        return '1024x1792';
      default:
        return '1024x1024';
    }
  }
}

class ImageViewPage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final String indexString;

  const ImageViewPage(
      {super.key, this.imageUrl, this.bytes, required this.indexString});

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object> image;
    if (imageUrl != null) {
      image = NetworkImage(imageUrl!);
    } else {
      image = MemoryImage(bytes!);
    }
    return Hero(
      tag: indexString,
      child: PhotoView(
        imageProvider: image,
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 2,
        enableRotation: true, // 이미지 회전 기능 활성화
      ),
    );
  }
}

class LikedImagesPage extends StatefulWidget {
  final List<SavedImageData> likedImages;
  final Function({required int index, required SavedImageData savedData})
      updateImageStatus;

  const LikedImagesPage(
      {super.key, required this.likedImages, required this.updateImageStatus});

  @override
  State<LikedImagesPage> createState() => _LikedImagesPageState();
}

class _LikedImagesPageState extends State<LikedImagesPage> {
  Map<int, Uint8List?> cachedImageData = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _cacheImageData();
  }

  void _cacheImageData() {
    for (int i = 0; i < widget.likedImages.length; i++) {
      for (var imageData in widget.likedImages[i].imageResponse.data) {
        if (imageData.base64 != null) {
          cachedImageData[i] = base64Decode(imageData.base64!);
        }
      }
    }
    setState(() {
      loading = false;
    });
  }

  // TODO notWork function
  void _unlikeImage(int index) {
    setState(() {
      SavedImageData savedImageData = widget.likedImages[index];
      savedImageData.isLiked = false;
      widget.updateImageStatus(index: index, savedData: savedImageData);
      // widget.likedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Images'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : widget.likedImages.isEmpty
              ? const Center(child: Text('No liked images'))
              : ListView.builder(
                  itemCount: widget.likedImages.length,
                  itemBuilder: (context, index) {
                    final image = widget.likedImages[index];
                    final imageData = image.imageResponse.data.first;
                    final bytes = cachedImageData[index];
                    final imageUrl = imageData.url ?? '';

                    return Column(
                      children: [
                        if (imageUrl.isNotEmpty) Image.network(imageUrl),
                        if (bytes != null) Image.memory(bytes),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(image.prompt),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite),
                          color: Colors.red,
                          onPressed: () => _unlikeImage(index),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
