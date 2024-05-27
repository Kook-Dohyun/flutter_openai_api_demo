<p align="center">
    <img src="https://raw.githubusercontent.com/Kook-Dohyun/flutter_openai_api_demo/main/assets/Untitled%20design.png"  width=90%/>
</p>

# **Flutter OpenAI API Demo**
This project is a personal project designed to test and learn OpenAI's API in a mobile application. It currently supports `Assistant` and `Images` API services. This document provides information on project setup, usage, technology stack, and other relevant details.

## Supported Features

### Assistant
- **Create, Modify, Delete, Clone**: You can create, modify, delete, and clone assistants.
- **Additional Message**: There is a feature to quote assistant responses and user responses.
- **Single Message Settings**: You can adjust `topP` and `temperature` values for each message.
- **Additional Instruction**: You can add additional instructions by entering `@`.
- **Stream Support**: All conversations are supported through streaming by default.
- **Token-Based Pricing Calculation**: Future pricing will be calculated based on `Prompt_tokens`, `completion_tokens`, `total_tokens`. For more details, see [OpenAi Pricing](https://openai.com/api/pricing/).

### Images
- **Local Cache Using Hive**: Images are stored using local cache memory (Hive). If the app data is deleted, the images are removed.
- **Save Images**: Images can be saved to the device's Pictures folder using a separate save button.
- **Master Prompt Support**: Test prompts provided by OpenAI are also supported in the form of master prompts, and can be changed and modified according to user preferences.
- **Supported Features**:
  - **Create**: Supports the image creation feature.
  - ~~**Edit**~~: (To be supported in the future)
  - ~~**Vision**~~: (To be supported in the future)

## How to Use

### API Key Input
The service operates based on the user's API key. The API key must be entered, and multiple API keys can be entered.

1. Run the app, then go to the settings menu.
2. Enter your API key.
3. The entered API key is stored through Hive.

### ~~API Endpoint Management (Optional)~~
~~You can manage the API endpoints within the app. If an API endpoint is updated, you can manually enter it to update.~~ (This feature is not currently implemented.)

# Setup

## 1. Flutter Setup

1. **Install Flutter**
   - First, Flutter must be installed. See [Flutter Official Documentation](https://flutter.dev/docs/get-started/install) for how to install Flutter.
   - Flutter version: 3.22.0 (on channel stable)
   - Dart version: 3.4.0

2. **Download Repository**
   - Open the terminal and use the following command to clone the repository:
    ```
    git clone https://github.com/Kook-Dohyun/flutter_openai_api_demo.git
    ```
3. **Navigate to Project Directory**
    ```
    cd <project directory>
    ```
    
4. **Run Flutter Doctor**
   - Execute the following command in the project root directory to ensure that Flutter is installed correctly:
   ```
   flutter doctor
   ```
    
5. **Download Packages**
   - If there are no issues, execute the following command to download the necessary packages:
   ```
   flutter pub get
   ```

6. **Troubleshooting**
   - If you encounter any issues, run the following commands to clear the cache and re-download the packages:
   ```
   flutter clean
   dart pub cache repair
   flutter pub get
   ```

7. **Check Firebase Configuration File**
   - Ensure that the `lib/firebase_options.dart` file has been created.

## 2. Firebase Setup

This section guides you through creating and setting up the Firebase configuration file.

1. **Install and Login to Firebase CLI**
   - Install the Firebase CLI. Refer to the [Firebase CLI Installation Guide](https://firebase.google.com/docs/cli?hl=en) for details.
   - Log in with Firebase CLI:
   ```
   firebase login
   ```

2. **Activate FlutterFire CLI**
   - Activate the FlutterFire CLI:
   ```
   dart pub global activate flutterfire_cli
   ```

3. **Configure Firebase Project**
   - Execute the following command to configure the Firebase project and platforms:
   ```
   flutterfire configure
   ```

4. **Initialize Firebase**
   - Check that the `lib/firebase_options.dart` file has been properly created.
   - Initialize Firebase in the `lib/main.dart` file:

### Additional Setup: Google Sign-In

This project is designed for Android and Windows platforms, and supports Google Sign-In.

1. Set up a Google project in the Firebase console, and add Android app.
2. Use Dart-only initialization to complete Firebase setup.

### Reference Documents

- [Firebase Official Documentation](https://firebase.google.com/docs/flutter/setup?hl=en&platform=ios)
- [FlutterFire CLI Documentation](https://firebase.flutter.dev/docs/cli/)
- [Dart-only initialization](https://firebase.flutter.dev/docs/manual-installation)
---

## Technology Stack

### Frameworks and Services
- **Flutter**: This project is built using Flutter, Google's UI toolkit.
- **Firebase**: Firebase is used to integrate and manage authentication and database functionalities. The database is used to backup user's Assistant conversations.
- **OpenAI API**: OpenAI API is utilized to provide Assistant and Images services.

### Packages
- **Hive**: A lightweight database for Flutter used for local data storage.
- **dio**: An HTTP client library used for network requests.
- **flutter_animate**: A library providing various animation effects.
- **flutter_dotenv**: Manages environment variables using .env files.
- **flutter_slidable**: Enables sliding actions on list items.
- **font_awesome_flutter**: Uses FontAwesome icons.
- **google_sign_in**: Integrates Google sign-in.
- **http**: A basic library for HTTP requests.
- **image_gallery_saver**: Allows saving images to the gallery.
- **intl**: Provides internationalization and localization capabilities.
- **photo_view**: Enables image zooming and panning functionalities.
- **provider**: A library for state management.
- **rxdart**: An extension library for reactive programming in Dart.

## References

For API-related content, refer to the [OpenAI Document](https://platform.openai.com/docs/overview) and [OpenAI API Reference](https://platform.openai.com/docs/api-reference/introduction).
