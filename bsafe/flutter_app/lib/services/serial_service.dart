// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Web Serial API ä¸²å£?åŠ¡
/// ?¨ä?è¿æ¥å®‰ä¿¡??UWB BU04 è®¾å?
class SerialService {
  static final SerialService _instance = SerialService._internal();
  factory SerialService() => _instance;
  SerialService._internal();

  dynamic _port;
  dynamic _reader;
  bool _isConnected = false;
  bool _isReading = false;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  bool get isConnected => _isConnected;

  /// æ£€?¥æ?è§ˆå™¨?¯å¦?¯æ? Web Serial API
  bool get isSupported {
    try {
      final navigator = web.window.navigator;
      return JsUtil.hasProperty(navigator, 'serial');
    } catch (e) {
      return false;
    }
  }

  /// è¯·æ?è¿æ¥ä¸²å£
  Future<bool> connect({int baudRate = 115200}) async {
    if (!isSupported) {
      debugPrint('Web Serial API ä¸æ”¯??);
      return false;
    }

    try {
      // è¯·æ??¨æˆ·?‰æ‹©ä¸²å£
      final serial = _getSerial();
      if (serial == null) return false;

      _port = await _requestPort(serial);
      if (_port == null) return false;

      // ?“å?ä¸²å£
      await _openPort(_port, baudRate);
      _isConnected = true;

      // å¼€å§‹è¯»?–æ•°??
      _startReading();

      debugPrint('ä¸²å£è¿æ¥?å?');
      return true;
    } catch (e) {
      debugPrint('ä¸²å£è¿æ¥å¤±è´¥: $e');
      _isConnected = false;
      return false;
    }
  }

  /// ?­å?ä¸²å£è¿æ¥
  Future<void> disconnect() async {
    _isReading = false;

    try {
      if (_reader != null) {
        await _cancelReader(_reader);
        _reader = null;
      }

      if (_port != null) {
        await _closePort(_port);
        _port = null;
      }
    } catch (e) {
      debugPrint('?­å?è¿æ¥?™è¯¯: $e');
    }

    _isConnected = false;
  }

  /// å¼€å§‹è¯»?–ä¸²??•°??
  void _startReading() async {
    if (_port == null || _isReading) return;

    _isReading = true;
    String buffer = '';

    try {
      _reader = _getReader(_port);

      while (_isReading && _reader != null) {
        final result = await _readData(_reader);
        if (result == null) break;

        final chunk = result;
        buffer += chunk;

        // ?‰è??†å‰²?°æ®
        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);

          if (line.isNotEmpty) {
            _dataController.add(line);
          }
        }
      }
    } catch (e) {
      debugPrint('è¯»å??°æ®?™è¯¯: $e');
    }

    _isReading = false;
  }

  /// ?‘é€æ•°?®åˆ°ä¸²å£
  Future<void> send(String data) async {
    if (_port == null || !_isConnected) return;

    try {
      await _writeData(_port, data);
    } catch (e) {
      debugPrint('?‘é€æ•°?®é?è¯? $e');
    }
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }

  // ===== JS Interop ?¹æ? =====

  dynamic _getSerial() {
    try {
      return JsUtil.getProperty(web.window.navigator, 'serial');
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> _requestPort(dynamic serial) async {
    try {
      final promise = JsUtil.callMethod(serial, 'requestPort', []);
      return await JsUtil.promiseToFuture(promise);
    } catch (e) {
      return null;
    }
  }

  Future<void> _openPort(dynamic port, int baudRate) async {
    final options = JsUtil.jsify({'baudRate': baudRate});
    final promise = JsUtil.callMethod(port, 'open', [options]);
    await JsUtil.promiseToFuture(promise);
  }

  Future<void> _closePort(dynamic port) async {
    final promise = JsUtil.callMethod(port, 'close', []);
    await JsUtil.promiseToFuture(promise);
  }

  dynamic _getReader(dynamic port) {
    final readable = JsUtil.getProperty(port, 'readable');
    return JsUtil.callMethod(readable, 'getReader', []);
  }

  Future<void> _cancelReader(dynamic reader) async {
    final promise = JsUtil.callMethod(reader, 'cancel', []);
    await JsUtil.promiseToFuture(promise);
  }

  Future<String?> _readData(dynamic reader) async {
    try {
      final promise = JsUtil.callMethod(reader, 'read', []);
      final result = await JsUtil.promiseToFuture(promise);

      final done = JsUtil.getProperty(result, 'done');
      if (done == true) return null;

      final value = JsUtil.getProperty(result, 'value');
      if (value == null) return null;

      // å°?Uint8Array è½¬æ¢ä¸ºå?ç¬¦ä¸²
      final decoder = web.TextDecoder();
      return decoder.decode(value);
    } catch (e) {
      return null;
    }
  }

  Future<void> _writeData(dynamic port, String data) async {
    final writable = JsUtil.getProperty(port, 'writable');
    final writer = JsUtil.callMethod(writable, 'getWriter', []);

    final encoder = web.TextEncoder();
    final encoded = encoder.encode(data);

    final promise = JsUtil.callMethod(writer, 'write', [encoded]);
    await JsUtil.promiseToFuture(promise);

    JsUtil.callMethod(writer, 'releaseLock', []);
  }
}

/// JS äº’æ?ä½œå·¥??
/// æ³¨æ?: æ­¤æ?ä»¶å?ä¾?Web å¹³å°ä½¿ç”¨ï¼Œæ??¢å¹³?°ä½¿??desktop_serial_service.dart
class JsUtil {
  static bool hasProperty(dynamic o, String name) {
    try {
      return (o as JSObject).has(name);
    } catch (e) {
      return false;
    }
  }

  static dynamic getProperty(dynamic o, String name) {
    return (o as JSObject).getProperty(name.toJS);
  }

  static dynamic callMethod(dynamic o, String method, List<dynamic> args) {
    final obj = o as JSObject;
    final jsMethod = obj.getProperty(method.toJS) as JSFunction;
    // å°‡å??¸è??›ç‚º JS é¡å?ï¼Œæ ¹?šå??¸æ•¸?èª¿??
    switch (args.length) {
      case 0:
        return jsMethod.callAsFunction(obj);
      case 1:
        return jsMethod.callAsFunction(obj, _toJsAny(args[0]));
      case 2:
        return jsMethod.callAsFunction(
            obj, _toJsAny(args[0]), _toJsAny(args[1]));
      case 3:
        return jsMethod.callAsFunction(
            obj, _toJsAny(args[0]), _toJsAny(args[1]), _toJsAny(args[2]));
      default:
        return jsMethod.callAsFunction(obj, _toJsAny(args[0]));
    }
  }

  static JSAny? _toJsAny(dynamic e) {
    if (e is JSAny) return e;
    if (e is Map) return e.jsify();
    if (e is String) return e.toJS;
    if (e is int) return e.toJS;
    if (e is double) return e.toJS;
    if (e is bool) return e.toJS;
    return null;
  }

  static dynamic jsify(Map<String, dynamic> map) {
    return map.jsify();
  }

  static Future<T> promiseToFuture<T>(dynamic promise) {
    return (promise as JSPromise).toDart.then((value) => value as T);
  }
}
