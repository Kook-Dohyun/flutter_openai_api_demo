<p align="center">
    <img src="https://raw.githubusercontent.com/Kook-Dohyun/flutter_openai_api_demo/main/assets/Untitled%20design.png"  width=90%/>
</p>

# **Flutter OpenAI API Demo**
이 프로젝트는 OpenAI의 API를 모바일 애플리케이션에서 테스트하고 학습하기 위해 설계된 개인 프로젝트입니다. 현재 `Assistant`와 `Images` API 서비스를 지원합니다. 이 문서는 프로젝트의 설정, 사용 방법, 기술 스택 및 기타 관련 정보를 제공합니다.

## 지원하는 기능

### Assistant
- **쓰레드 관리**: 여러 대화를 효율적으로 관리할 수 있습니다.
- **토큰 기반 가격 계산**: 사용된 토큰 수에 기반하여 가격을 계산하고 표시합니다. 자세한 내용은 [OpenAi Pricing](https://openai.com/api/pricing/)을 참조하세요.

### Images
- **Hive를 이용한 임시 저장**: 이미지를 임시로 저장할 수 있습니다.
- **디바이스에 저장**: 필요에 따라 이미지를 디바이스의 Pictures 폴더에 저장할 수 있습니다.

## 사용 방법

### API 키 입력
서비스는 사용자의 API 키를 기반으로 작동합니다. API 키는 반드시 입력해야 하며, 복수의 API 키를 입력할 수 있습니다.

1. 앱을 실행한 후, 설정 메뉴로 이동합니다.
2. API 키를 입력합니다.
3. 입력된 API 키는 Hive를 통해 저장됩니다.

### ~~API 엔드포인트 관리 (선택 사항)~~
~~앱 내에서 API의 엔드포인트를 관리할 수 있습니다. API 엔드포인트가 업데이트되는 경우, 수동으로 입력하여 업데이트할 수 있습니다.~~ (현재 이 기능은 구현되지 않았습니다.)

# 설정

## 1. 첫 번째 설정

1. **Flutter 설치**
    - 먼저, Flutter가 설치되어 있어야 합니다. Flutter를 설치하는 방법은 [Flutter 공식 문서](https://flutter.dev/docs/get-started/install)를 참고하세요.

2. **레포지토리 다운로드**
    - 터미널을 열고, 다음 명령어를 사용하여 레포지토리를 클론합니다:
    ```sh
    git clone https://github.com/Kook-Dohyun/flutter_openai_api_demo.git
    ```

3. **프로젝트 디렉토리로 이동**
    ```sh
    cd <프로젝트 디렉토리>
    ```

4. **Flutter Doctor 실행**
    - 프로젝트 루트 디렉토리에서 다음 명령어를 실행하여 Flutter가 올바르게 설치되었는지 확인합니다:
    ```sh
    flutter doctor
    ```

5. **패키지 다운로드**
    - 문제가 없다면 다음 명령어를 실행하여 필요한 패키지를 다운로드합니다:
    ```sh
    flutter pub get
    ```

6. **문제 해결**
    - 만약 문제가 발생하면, 다음 명령어를 실행하여 캐시를 초기화하고 패키지를 다시 다운로드합니다:
    ```sh
    flutter clean
    dart pub cache repair
    flutter pub get
    ```

7. **Firebase 설정 파일 확인**
    - `lib/firebase_options.dart` 파일이 생성되었는지 확인합니다.

## 2. Firebase 설정

Firebase 설정 파일을 생성하고 설정 정보를 추가하는 방법을 안내합니다.

1. **Firebase CLI 설치 및 로그인**
    - Firebase CLI를 설치합니다. [Firebase CLI 설치 가이드](https://firebase.google.com/docs/cli?hl=ko&_gl=1*c6e9w5*_up*MQ..*_ga*MjAzNzQ0NTk5MS4xNzE2NjYyNDU4*_ga_CW55HF8NVT*MTcxNjY2MjQ1Ny4xLjAuMTcxNjY2MjQ1Ny4wLjAuMA..#setup_update_cli)를 참고하세요.
    - Firebase CLI로 로그인합니다:
    ```sh
    firebase login
    ```

2. **FlutterFire CLI 활성화**
    - FlutterFire CLI를 활성화합니다:
    ```sh
    dart pub global activate flutterfire_cli
    ```

3. **Firebase 프로젝트 구성**
    - 다음 명령어를 실행하여 Firebase 프로젝트와 플랫폼을 구성합니다:
    ```sh
    flutterfire configure
    ```

4. **Firebase 초기화**
    - `lib/firebase_options.dart` 가 정상적으로 생성 됐는지 확인합니다.
    - `lib/main.dart` 파일에서 Firebase를 초기화합니다:
        
    ```dart
    import 'package:flutter/material.dart';
    import 'package:firebase_core/firebase_core.dart';
    import 'firebase_options.dart';

    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      runApp(MyApp());
    } 
    ```


### 추가 설정: Google 로그인

이 프로젝트는 안드로이드와 윈도우 기반으로 제작되었으며, Google 로그인을 지원합니다.

1. Firebase 콘솔에서 Google 프로젝트를 설정하고, Android 앱을 추가합니다.
2. Dart-only 초기화를 사용하여 Firebase 설정을 완료합니다.

### 참고 문서

- [Firebase 공식 문서](https://firebase.google.com/docs/flutter/setup?hl=ko&platform=ios)
- [FlutterFire CLI 문서](https://firebase.flutter.dev/docs/cli/)
- [Dart-only initialization](https://firebase.flutter.dev/docs/manual-installation)
---

## 기술 스택

### 플레임워크 및 서비스
- **Flutter**: 이 프로젝트는 Google의 UI toolkit인 Flutter를 사용하여 제작되었습니다.
- **Firebase**:Firebase를 사용하여 인증 및 데이터베이스 기능을 통합하고 관리합니다. 데이터베이스는 사용자의 Assistant 대화를 백업하는 용도로 사용됩니다.
- **OpenAI API**: OpenAI API를 사용하여 Assistant와 Images 서비스를 제공합니다.

### 패키지
- **Hive**: Flutter용 경량 데이터베이스로, 로컬 데이터 저장에 사용됩니다.
- **dio**: HTTP 클라이언트 라이브러리로, 네트워크 요청에 사용됩니다.
- **flutter_animate**: 다양한 애니메이션 효과를 제공하는 라이브러리입니다.
- **flutter_dotenv**: .env 파일을 사용하여 환경 변수를 관리합니다.
- **flutter_slidable**: 리스트 아이템을 슬라이드하여 다양한 액션을 수행할 수 있도록 합니다.
- **font_awesome_flutter**: FontAwesome 아이콘을 사용합니다.
- **google_sign_in**: Google 로그인을 통합합니다.
- **http**: HTTP 요청을 위한 기본 라이브러리입니다.
- **image_gallery_saver**: 이미지를 갤러리에 저장할 수 있습니다.
- **intl**: 국제화 및 지역화 기능을 제공합니다.
- **photo_view**: 이미지 확대/축소 및 이동을 가능하게 하는 라이브러리입니다.
- **provider**: 상태 관리를 위한 라이브러리입니다.
- **rxdart**: Dart의 반응형 프로그래밍을 위한 확장 라이브러리입니다.

## 참고

API관련 내용은 [OpenAi Document](https://platform.openai.com/docs/overview)과 [OpenAi API Reference](https://platform.openai.com/docs/api-reference/introduction)를 참조하세요
