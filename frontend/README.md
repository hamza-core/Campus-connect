# project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android dependencies

The app uses Flutter's Android minimum SDK of 24, which also satisfies
`flutter_secure_storage` and `image_picker_android`. The main manifest declares
Internet access for the API. Android's system picker handles image
selection without a broad storage permission.

The illustration assets are bundled from `assets/illustrations/`. The splash
uses the animated logo fallback because no Lottie splash asset was supplied.
