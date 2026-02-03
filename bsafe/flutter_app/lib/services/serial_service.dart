// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

/// Web Serial API 串口服务
/// 用于连接安信可 UWB BU04 设备
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

  /// 检查浏览器是否支持 Web Serial API
  bool get isSupported {
    try {
      final navigator = web.window.navigator;
      return js_util.hasProperty(navigator, 'serial');
    } catch (e) {
      return false;
    }
  }

  /// 请求连接串口
  Future<bool> connect({int baudRate = 115200}) async {
    if (!isSupported) {
      debugPrint('Web Serial API 不支持');
      return false;
    }

    try {
      // 请求用户选择串口
      final serial = _getSerial();
      if (serial == null) return false;

      _port = await _requestPort(serial);
      if (_port == null) return false;

      // 打开串口
      await _openPort(_port, baudRate);
      _isConnected = true;

      // 开始读取数据
      _startReading();

      debugPrint('串口连接成功');
      return true;
    } catch (e) {
      debugPrint('串口连接失败: $e');
      _isConnected = false;
      return false;
    }
  }

  /// 断开串口连接
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
      debugPrint('断开连接错误: $e');
    }

    _isConnected = false;
  }

  /// 开始读取串口数据
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

        // 按行分割数据
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
      debugPrint('读取数据错误: $e');
    }

    _isReading = false;
  }

  /// 发送数据到串口
  Future<void> send(String data) async {
    if (_port == null || !_isConnected) return;

    try {
      await _writeData(_port, data);
    } catch (e) {
      debugPrint('发送数据错误: $e');
    }
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }

  // ===== JS Interop 方法 =====

  dynamic _getSerial() {
    try {
      return js_util.getProperty(web.window.navigator, 'serial');
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> _requestPort(dynamic serial) async {
    try {
      final promise = js_util.callMethod(serial, 'requestPort', []);
      return await js_util.promiseToFuture(promise);
    } catch (e) {
      return null;
    }
  }

  Future<void> _openPort(dynamic port, int baudRate) async {
    final options = js_util.jsify({'baudRate': baudRate});
    final promise = js_util.callMethod(port, 'open', [options]);
    await js_util.promiseToFuture(promise);
  }

  Future<void> _closePort(dynamic port) async {
    final promise = js_util.callMethod(port, 'close', []);
    await js_util.promiseToFuture(promise);
  }

  dynamic _getReader(dynamic port) {
    final readable = js_util.getProperty(port, 'readable');
    return js_util.callMethod(readable, 'getReader', []);
  }

  Future<void> _cancelReader(dynamic reader) async {
    final promise = js_util.callMethod(reader, 'cancel', []);
    await js_util.promiseToFuture(promise);
  }

  Future<String?> _readData(dynamic reader) async {
    try {
      final promise = js_util.callMethod(reader, 'read', []);
      final result = await js_util.promiseToFuture(promise);

      final done = js_util.getProperty(result, 'done');
      if (done == true) return null;

      final value = js_util.getProperty(result, 'value');
      if (value == null) return null;

      // 将 Uint8Array 转换为字符串
      final decoder = web.TextDecoder();
      return decoder.decode(value);
    } catch (e) {
      return null;
    }
  }

  Future<void> _writeData(dynamic port, String data) async {
    final writable = js_util.getProperty(port, 'writable');
    final writer = js_util.callMethod(writable, 'getWriter', []);

    final encoder = web.TextEncoder();
    final encoded = encoder.encode(data);

    final promise = js_util.callMethod(writer, 'write', [encoded]);
    await js_util.promiseToFuture(promise);

    js_util.callMethod(writer, 'releaseLock', []);
  }
}

/// JS 互操作工具
/// 注意: 此文件僅供 Web 平台使用，桌面平台使用 desktop_serial_service.dart
class js_util {
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
    // 將參數轉換為 JS 類型，根據參數數量調用
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
