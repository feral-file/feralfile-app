import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/mime_type.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';

String _cacheKey = 'AUCache';

class Info {
  Info(
    this.url,
    this.fileExt,
    this.taskId,
    this.localFile,
    this.task,
  );

  final String url;
  final String fileExt;
  final String taskId;
  final String localFile;
  final Completer<FileServiceResponse> task;
}

class AUImageCacheManage extends CacheManager with ImageCacheManager {
  factory AUImageCacheManage() => _instance;

  AUImageCacheManage._()
      : super(
          Config(
            _cacheKey,
            fileService: AuFileService(),
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 10000,
          ),
        );
  static final AUImageCacheManage _instance = AUImageCacheManage._();
}

class AuFileServiceResponse extends FileServiceResponse {
  AuFileServiceResponse({
    required String filePath,
    required this.fileExt,
  }) : _localFile = File(filePath);
  final File _localFile;
  final String fileExt;
  final DateTime _validTill = DateTime.now().add(const Duration(days: 30));

  @override
  // ignore: discarded_futures
  Stream<List<int>> get content => _localFile.readAsBytes().asStream();

  @override
  int? get contentLength => _localFile.lengthSync();

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.$fileExt';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => _validTill;
}

class AuFileService extends FileService {
  factory AuFileService() => _instance;

  AuFileService._();

  static final AuFileService _instance = AuFileService._();

  final Map<String, Info> _taskId2Info = {};

  final ReceivePort _port = ReceivePort();
  late String _saveDir;

  Future<dynamic> setup() async {
    final tempDir = (await getTemporaryDirectory()).path;
    _saveDir = '$tempDir/$_cacheKey/';
    await Directory(_saveDir).create(recursive: true);
    FlutterImageCompress.validator.ignoreCheckExtName = true;
    IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    _port.listen((data) async {
      if (data is List && data.length >= 3) {
        final id = data[0] as String;
        final status = DownloadTaskStatus.fromInt(data[1] as int);
        final progress = data[2] as int;
        await _downloadCallback(id, status, progress);
      } else {
        log.info('Invalid data from downloader_send_port: $data');
        unawaited(
          Sentry.captureMessage(
            'Invalid data from downloader_send_port: $data',
          ),
        );
      }
    });
  }

  Future<void> _downloadCallback(
    String id,
    DownloadTaskStatus status,
    int progress,
  ) async {
    final info = _taskId2Info[id];
    if (info != null) {
      if (status == DownloadTaskStatus.complete) {
        final localFile = File(_saveDir + info.localFile);
        final fileSize = await localFile.length();
        if (fileSize <= 0) {
          log.info('File is empty ${info.url}');
          info.task.completeError(Exception('File is empty ${info.url}'));
        } else if (info.url.startsWith(Environment.cloudFlareImageUrlPrefix)) {
          info.task.complete(
            AuFileServiceResponse(
              filePath: _saveDir + info.localFile,
              fileExt: info.fileExt,
            ),
          );
        } else {
          try {
            final originalFile = _saveDir + info.localFile;
            final compressedFile = '${_saveDir}resized_${info.localFile}.jpeg';
            await FlutterImageCompress.compressAndGetFile(
              originalFile,
              compressedFile,
              quality: 90,
            );
            final isFileExists = await File(compressedFile).exists();
            if (isFileExists) {
              await File(originalFile).delete();
              info.task.complete(
                AuFileServiceResponse(
                  filePath: compressedFile,
                  fileExt: 'jpeg',
                ),
              );
            } else {
              info.task.complete(
                AuFileServiceResponse(
                  filePath: originalFile,
                  fileExt: info.fileExt,
                ),
              );
            }
          } catch (e) {
            log.info('Compress image failed ${info.url} Error: $e');
            unawaited(
              Sentry.captureException(
                'Compress image failed ${info.url} Error',
              ),
            );
            info.task.complete(
              AuFileServiceResponse(
                filePath: _saveDir + info.localFile,
                fileExt: info.fileExt,
              ),
            );
          }
        }
        _taskId2Info.remove(id);
      } else if (status == DownloadTaskStatus.failed) {
        log.info('[AuFileService] Download failed: ${info.url} ${info.taskId}');
        unawaited(Sentry.captureMessage('Download failed ${info.url}'));
        info.task.completeError(Exception('Download failed ${info.url}'));
        _taskId2Info.remove(id);
      } else if (status == DownloadTaskStatus.canceled) {
        log.info('[AuFileService] Download canceled: ${info.url}');
        unawaited(Sentry.captureMessage('Download canceled ${info.url}'));
        info.task.completeError(Exception('Download canceled ${info.url}'));
        _taskId2Info.remove(id);
      }
    }
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    var info =
        _taskId2Info.values.firstWhereOrNull((element) => element.url == url);
    if (info == null) {
      final fileInfo = await getFileInfo(url);

      if (!(Uri.tryParse(url)?.hasAbsolutePath ?? false)) {
        unawaited(Sentry.captureMessage('[AuFileService] Invalid url $url'));
        return Future.error(Exception('Invalid url $url'));
      }

      final fileName = '${md5.convert(utf8.encode(url))}.${fileInfo.extension}';
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        headers: headers ?? {},
        savedDir: _saveDir,
        fileName: fileName,
        showNotification: kDebugMode,
        openFileFromNotification: kDebugMode,
        timeout: 15000,
      );
      if (taskId == null) {
        unawaited(
          Sentry.captureMessage('Failed to create download task for $url'),
        );
        return Future.error(
          Exception('Failed to create download task for $url'),
        );
      }
      info = Info(url, fileInfo.extension, taskId, fileName, Completer());
      _taskId2Info[taskId] = info;
    }
    return info.task.future;
  }
}
