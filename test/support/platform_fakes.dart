import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records wakelock_plus calls made through its pigeon channel.
class FakeWakelock {
  static const _toggleChannel = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  static const _codec = _PigeonMessageCodec();

  /// Every requested state, in order: true for enable, false for disable.
  final List<bool> toggles = [];

  /// The state last asked for, or null when nothing was requested yet.
  bool? get enabled => toggles.isEmpty ? null : toggles.last;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      _toggleChannel,
      (ByteData? message) async {
        final arguments = _codec.decodeMessage(message) as List<Object?>;
        final toggleMessage = arguments.single as List<Object?>;
        toggles.add(toggleMessage.first as bool);
        return _codec.encodeMessage(<Object?>[]);
      },
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_toggleChannel, null);
  }
}

/// Reads pigeon data classes (encoded as custom types 129+) as their field lists.
class _PigeonMessageCodec extends StandardMessageCodec {
  const _PigeonMessageCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    return type >= 129 ? readValue(buffer) : super.readValueOfType(type, buffer);
  }
}

/// Records share_plus calls made through its method channel.
class FakeShare {
  static const _channel = MethodChannel('dev.fluttercommunity.plus/share');

  final List<Map<Object?, Object?>> shares = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        if (call.method == 'share') {
          shares.add(call.arguments as Map<Object?, Object?>);
        }
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  }
}

/// Records url_launcher calls made through its method channel. Every URL can be launched.
class FakeUrlLauncher {
  static const _channel = MethodChannel('plugins.flutter.io/url_launcher');

  final List<String> launchedUrls = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        if (call.method == 'launch') {
          launchedUrls.add((call.arguments as Map<Object?, Object?>)['url'] as String);
        }
        return true;
      },
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  }
}

/// Records in_app_review calls made through its method channel.
class FakeInAppReview {
  static const _channel = MethodChannel('dev.britannio.in_app_review');

  /// Every call, in order, e.g. "isAvailable", "requestReview".
  final List<String> calls = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        calls.add(call.method);
        return call.method == 'isAvailable' ? true : null;
      },
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  }
}

/// Answers path_provider's method channel with a temporary directory of the test.
class FakePathProvider {
  static const _channel = MethodChannel('plugins.flutter.io/path_provider');

  final Directory directory = Directory.systemTemp.createTempSync('spiewnik_paths_');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async => directory.path,
    );
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    directory.deleteSync(recursive: true);
  }
}
