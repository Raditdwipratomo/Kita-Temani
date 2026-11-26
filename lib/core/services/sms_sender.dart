import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/config/env.dart';

enum ContactSmsDeliveryStatus {
  sending,
  sent,
  failed,
  retrying,
}

abstract interface class SmsSender {
  Future<void> sendToAll(Iterable<String> numbers, String text);
  Future<bool> sendToSingle(String number, String text);
}

class AndroidSmsSender implements SmsSender {
  AndroidSmsSender({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('id.kitatemani/sms');

  final MethodChannel _channel;

  @override
  Future<void> sendToAll(Iterable<String> numbers, String text) async {
    final targetNumbers = numbers.where((n) => n.trim().isNotEmpty).toList();
    if (targetNumbers.isEmpty) return;

    await _channel.invokeMethod<void>('sendSms', {
      'numbers': targetNumbers,
      'text': text,
    });
  }

  @override
  Future<bool> sendToSingle(String number, String text) async {
    try {
      await sendToAll([number], text);
      return true;
    } on Object {
      return false;
    }
  }
}

class DummySmsSender implements SmsSender {
  bool simulateFailure = false;
  final List<String> sentLogs = [];

  @override
  Future<void> sendToAll(Iterable<String> numbers, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (simulateFailure) {
      throw PlatformException(
        code: 'NO_SIGNAL',
        message: 'Tidak ada sinyal seluler atau pulsa habis.',
      );
    }
    for (final number in numbers) {
      sentLogs.add('$number: $text');
    }
  }

  @override
  Future<bool> sendToSingle(String number, String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (simulateFailure) return false;
    sentLogs.add('$number: $text');
    return true;
  }
}

final smsSenderProvider = Provider<SmsSender>((ref) {
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !Env.forceDummyData) {
    return AndroidSmsSender();
  }
  return DummySmsSender();
});
