enum Model {
  dalle2,
  dalle3,
}

enum Quality {
  standard,
  hd,
}

enum ImgResponseFormat {
  b64Json,
  url,
}

enum ImageSize {
  small256x256,
  medium512x512,
  large1024x1024,
  wide1792x1024,
  tall1024x1792,
}

enum Style {
  vivid,
  natural,
}

class CreateImageRequest {
  final String prompt;
  final Model model;
  final int n;
  final Quality? quality;
  final ImgResponseFormat responseFormat;
  final ImageSize size;
  final Style? style;
  final String? user;

  CreateImageRequest._({
    required this.prompt,
    required this.model,
    required this.n,
    this.quality,
    required this.responseFormat,
    required this.size,
    this.style,
    this.user,
  });

  factory CreateImageRequest.dalle2({
    required String prompt,
    int n = 1,
    ImgResponseFormat responseFormat = ImgResponseFormat.url,
    ImageSize size = ImageSize.large1024x1024,
    String? user,
  }) {
    if (n < 1 || n > 4) {
      throw ArgumentError('For dalle-2, n must be between 1 and 4.');
    }
    if (!_isValidDalle2Size(size)) {
      throw ArgumentError(
          'Invalid size for dalle-2. Must be one of 256x256, 512x512, or 1024x1024.');
    }
    return CreateImageRequest._(
      prompt: prompt,
      model: Model.dalle2,
      n: n,
      responseFormat: responseFormat,
      size: size,
      user: user,
    );
  }

  factory CreateImageRequest.dalle3({
    required String prompt,
    ImgResponseFormat responseFormat = ImgResponseFormat.url,
    ImageSize size = ImageSize.large1024x1024,
    Style style = Style.vivid,
    String? user,
  }) {
    if (!_isValidDalle3Size(size)) {
      throw ArgumentError(
          'Invalid size for dalle-3. Must be one of 1024x1024, 1792x1024, or 1024x1792.');
    }
    return CreateImageRequest._(
      prompt: prompt,
      model: Model.dalle3,
      n: 1,
      quality: Quality.hd,
      responseFormat: responseFormat,
      size: size,
      style: style,
      user: user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'model': _modelToString(model),
      'n': n,
      if (quality != null) 'quality': quality?.toString().split('.').last,
      'response_format': _responseFormatToString(responseFormat),
      'size': _sizeToString(size),
      if (style != null) 'style': style?.toString().split('.').last,
      if (user != null) 'user': user,
    };
  }

  static bool _isValidDalle2Size(ImageSize size) {
    return size == ImageSize.small256x256 ||
        size == ImageSize.medium512x512 ||
        size == ImageSize.large1024x1024;
  }

  static bool _isValidDalle3Size(ImageSize size) {
    return size == ImageSize.large1024x1024 ||
        size == ImageSize.wide1792x1024 ||
        size == ImageSize.tall1024x1792;
  }

  String _modelToString(Model model) {
    switch (model) {
      case Model.dalle2:
        return 'dall-e-2';
      case Model.dalle3:
        return 'dall-e-3';
      default:
        return 'dall-e-2';
    }
  }

  String _responseFormatToString(ImgResponseFormat format) {
    switch (format) {
      case ImgResponseFormat.url:
        return 'url';
      case ImgResponseFormat.b64Json:
        return 'b64_json';
      default:
        return 'url';
    }
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

class SavedImageData {
  final String prompt;
  final ImageResponse imageResponse;
  bool isLiked;

  SavedImageData(
      {required this.prompt,
      required this.imageResponse,
      this.isLiked = false});

  factory SavedImageData.fromJson(Map<String, dynamic> json) {
    return SavedImageData(
      prompt: json['prompt'],
      imageResponse: ImageResponse.fromJson(Map<String, dynamic>.from(
          json['image_response'].cast<dynamic, dynamic>())),
      isLiked: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'image_response': imageResponse.toJson(),
      'is_liked': isLiked,
    };
  }
}

class ImageResponse {
  final int created;
  final List<ImageData> data;

  ImageResponse({required this.created, required this.data});

  factory ImageResponse.fromJson(Map<String, dynamic> json) {
    return ImageResponse(
      created: json['created'],
      data: List<ImageData>.from(json['data'].map((item) => ImageData.fromJson(
          Map<String, dynamic>.from(item.cast<dynamic, dynamic>())))),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'created': created,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class ImageData {
  final String? revisedPrompt;
  final String? url;
  final String? base64;

  ImageData(
      {required this.revisedPrompt, required this.url, required this.base64});

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      revisedPrompt: json['revised_prompt'],
      url: json['url'],
      base64: json['b64_json'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'revised_prompt': revisedPrompt,
      'url': url,
      'b64_json': base64,
    };
  }
}
