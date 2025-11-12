import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/utils.dart';

/// 仅在 Release 启用“应用内日志 & 日志UI”
/// - debug/profile：不收集日志、不写文件、不显示UI（通过 Log.showLogUI）
/// - release：一切照常
const bool _LOG_ENABLED = kReleaseMode;

class Log {
  static LogFileWriter? logFileWriter;

  /// UI 用这个开关判断是否显示“日志按钮/入口”
  static const bool showLogUI = _LOG_ENABLED;

  static void initWriter() {
    if (!_LOG_ENABLED) return;
    logFileWriter = LogFileWriter();
  }

  static void disposeWriter() {
    if (!_LOG_ENABLED) return;
    logFileWriter?.close();
    logFileWriter = null;
  }

  static void writeLog(content, [Level level = Level.info]) {
    if (!_LOG_ENABLED) return;
    logFileWriter?.write("[${level.name.toUpperCase()}] $_currentTime：$content");
  }

  static RxList<DebugLogModel> debugLogs = <DebugLogModel>[].obs;

  /// 非 release 不入队（避免占内存、也避免出现UI内容）
  static void addDebugLog(String content, Color? color) {
    if (!_LOG_ENABLED) return;
    if (content.contains("请求响应")) {
      content = content.split("\n").join('\n💡 ');
    }
    try {
      debugLogs.insert(0, DebugLogModel(DateTime.now(), content, color: color));
    } catch (e) {
      if (kDebugMode) {
        // 这里仅在开发控制台提示，不走应用内日志
        debugPrint(e.toString());
      }
    }
  }

  static final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  static void d(String message, [bool writeFile = true]) {
    if (!_LOG_ENABLED) {
      if (kDebugMode) debugPrint(message);
      return;
    }
    addDebugLog(message, Colors.orange);
    logger.d("${DateTime.now()}\n$message");
    if (writeFile) writeLog(message, Level.debug);
  }

  static void i(String message, [bool writeFile = true]) {
    if (!_LOG_ENABLED) {
      if (kDebugMode) debugPrint(message);
      return;
    }
    addDebugLog(message, Colors.blue);
    logger.i("${DateTime.now()}\n$message");
    if (writeFile) writeLog(message, Level.info);
  }

  static void e(String message, StackTrace stackTrace, [bool writeFile = true]) {
    if (!_LOG_ENABLED) {
      if (kDebugMode) debugPrint('$message\n$stackTrace');
      return;
    }
    addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
    logger.e("${DateTime.now()}\n$message", stackTrace: stackTrace);
    if (writeFile) writeLog("$message\n$stackTrace", Level.error);
  }

  static void w(String message, [bool writeFile = true]) {
    if (!_LOG_ENABLED) {
      if (kDebugMode) debugPrint(message);
      return;
    }
    addDebugLog(message, Colors.pink);
    logger.w("${DateTime.now()}\n$message");
    if (writeFile) writeLog(message, Level.warning);
  }

  static void logPrint(dynamic obj, [bool writeFile = true]) {
    if (!_LOG_ENABLED) {
      if (kDebugMode) print(obj);
      return;
    }
    addDebugLog(obj.toString(), Colors.red);
    if (writeFile) writeLog(obj, Level.info);
    if (kDebugMode) {
      // 控制台输出保留，方便本地调试
      print(obj);
    }
  }

  static String get _currentTime => Utils.timeFormat.format(DateTime.now());
}

class LogFileWriter {
  late String fileName;
  LogFileWriter() {
    final dt = DateFormat("yyyy-MM-dd HH-mm-ss").format(DateTime.now());
    fileName = "$dt.log";
    initFile();
  }

  IOSink? fileWriter;

  void initFile() async {
    if (!_LOG_ENABLED) return;
    final supportDir = await getApplicationSupportDirectory();
    final logDir = Directory("${supportDir.path}/log");
    if (!await logDir.exists()) {
      await logDir.create();
    }
    final logFile = File("${logDir.path}/$fileName");
    fileWriter = logFile.openWrite(mode: FileMode.append);
    writeSystemInfo();
  }

  void write(String content) {
    if (!_LOG_ENABLED) return;
    fileWriter?.write(content);
    fileWriter?.write("\r\n");
  }

  Future close() async {
    await fileWriter?.close();
  }

  void writeSystemInfo() async {
    if (!_LOG_ENABLED) return;
    final deviceInfo = DeviceInfoPlugin();
    write("System Info:");
    write("Current Time: ${DateTime.now()}");
    write("Platform: ${Platform.operatingSystem}");
    write("Version: ${Platform.operatingSystemVersion}");
    write("Local: ${Platform.localeName}");
    write("App Version: ${Utils.packageInfo.version}+${Utils.packageInfo.buildNumber}");
    if (Platform.isAndroid) {
      write((await deviceInfo.androidInfo).data.toString());
    } else if (Platform.isIOS) {
      write((await deviceInfo.iosInfo).data.toString());
    } else if (Platform.isLinux) {
      write((await deviceInfo.linuxInfo).data.toString());
    } else if (Platform.isMacOS) {
      write((await deviceInfo.macOsInfo).data.toString());
    } else if (Platform.isWindows) {
      write((await deviceInfo.windowsInfo).data.toString());
    }
    write("End System Info");
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
