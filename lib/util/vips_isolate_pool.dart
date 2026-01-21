//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:isolate';

import 'package:autonomy_flutter/util/log.dart';
import 'package:libvips_ffi/libvips_ffi.dart';

/// Request message for isolate communication
class _VipsResizeRequest {
  _VipsResizeRequest({
    required this.id,
    required this.inputPath,
    required this.outputPath,
    required this.targetWidth,
    required this.targetHeight,
    required this.responsePort,
  });

  final int id;
  final String inputPath;
  final String outputPath;
  final int? targetWidth;
  final int? targetHeight;
  final SendPort responsePort;
}

/// Response message from isolate
class _VipsResizeResponse {
  _VipsResizeResponse({
    required this.id,
    this.success = false,
    this.error,
  });

  final int id;
  final bool success;
  final String? error;
}

/// Single isolate worker for image resizing
class _VipsWorker {
  _VipsWorker(this.id);

  final int id;
  Isolate? _isolate;
  SendPort? _sendPort;
  bool _isReady = false;
  bool _isBusy = false;

  bool get isReady => _isReady && !_isBusy;
  bool get isBusy => _isBusy;

  /// Initialize the isolate worker
  Future<void> initialize() async {
    final receivePort = ReceivePort();
    
    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
      debugName: 'VipsWorker-$id',
    );

    // Wait for the isolate to send its SendPort
    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      }
    });

    _sendPort = await completer.future;
    _isReady = true;
    log.info('[VipsWorker-$id] Initialized');
  }

  /// Process a resize request from file to file
  Future<bool> resizeFile({
    required String inputPath,
    required String outputPath,
    int? targetWidth,
    int? targetHeight,
  }) async {
    if (!_isReady || _sendPort == null) {
      throw StateError('Worker not initialized');
    }

    _isBusy = true;

    try {
      final responsePort = ReceivePort();
      final requestId = DateTime.now().millisecondsSinceEpoch;

      final request = _VipsResizeRequest(
        id: requestId,
        inputPath: inputPath,
        outputPath: outputPath,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        responsePort: responsePort.sendPort,
      );

      _sendPort!.send(request);

      // Wait for response
      final response = await responsePort.first as _VipsResizeResponse;
      responsePort.close();

      if (response.error != null) {
        log.warning('[VipsWorker-$id] Resize failed: ${response.error}');
        return false;
      }

      return response.success;
    } finally {
      _isBusy = false;
    }
  }

  /// Dispose the worker
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isReady = false;
    log.info('[VipsWorker-$id] Disposed');
  }

  /// Isolate entry point
  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    
    // Send our SendPort to the main isolate
    mainSendPort.send(receivePort.sendPort);

    // Initialize libvips in this isolate
    try {
      initVips();
    } catch (e) {
      // Ignore if already initialized
    }

    // Listen for resize requests
    receivePort.listen((message) {
      if (message is _VipsResizeRequest) {
        _handleResizeRequest(message);
      }
    });
  }

  /// Handle resize request in isolate (file-based)
  static void _handleResizeRequest(_VipsResizeRequest request) {
    try {
      // Load from file
      final pipeline = VipsPipeline.fromFile(request.inputPath);

      try {
        // Calculate scale if needed
        if (request.targetWidth != null || request.targetHeight != null) {
          final originalWidth = pipeline.image.width;
          final originalHeight = pipeline.image.height;

          var scale = 1.0;

          if (request.targetWidth != null && request.targetHeight != null) {
            // Both dimensions specified - fit within bounds
            final scaleW = request.targetWidth! / originalWidth;
            final scaleH = request.targetHeight! / originalHeight;
            scale = scaleW < scaleH ? scaleW : scaleH;
          } else if (request.targetWidth != null) {
            // Width only
            scale = request.targetWidth! / originalWidth;
          } else if (request.targetHeight != null) {
            // Height only
            scale = request.targetHeight! / originalHeight;
          }

          // Only resize if scaling down
          if (scale < 1.0) {
            pipeline.resize(scale);
          }
        }

        // Save to output file
        pipeline.toFile(request.outputPath);

        request.responsePort.send(
          _VipsResizeResponse(
            id: request.id,
            success: true,
          ),
        );
      } finally {
        pipeline.dispose();
      }
    } catch (e) {
      request.responsePort.send(
        _VipsResizeResponse(
          id: request.id,
          success: false,
          error: e.toString(),
        ),
      );
    }
  }
}

/// Pool of isolate workers for parallel image processing
class VipsIsolatePool {
  VipsIsolatePool({this.poolSize = 4});

  final int poolSize;
  final List<_VipsWorker> _workers = [];
  bool _initialized = false;
  bool _isInitializing = false;
  final _initLock = Completer<void>();

  /// Initialize the pool
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (_isInitializing) {
      // Another thread is initializing, wait for it
      await _initLock.future;
      return;
    }

    // Mark as initializing before starting
    _isInitializing = true;

    try {
      log.info('[VipsIsolatePool] Initializing pool with $poolSize workers...');
      
      // Initialize libvips in main isolate
      try {
        initVips();
      } catch (e) {
        // Already initialized, ignore
      }

      // Create workers
      for (var i = 0; i < poolSize; i++) {
        final worker = _VipsWorker(i);
        await worker.initialize();
        _workers.add(worker);
      }

      _initialized = true;
      _initLock.complete();
      log.info('[VipsIsolatePool] Pool initialized with ${_workers.length} workers');
    } catch (e, stackTrace) {
      log.severe('[VipsIsolatePool] Failed to initialize: $e\n$stackTrace');
      _isInitializing = false; // Reset flag on error
      _initLock.completeError(e);
      rethrow;
    }
  }

  /// Resize image file using an available worker
  Future<bool> resizeFile({
    required String inputPath,
    required String outputPath,
    int? targetWidth,
    int? targetHeight,
  }) async {
    await initialize();

    if (!_initialized || _workers.isEmpty) {
      throw StateError('Pool not initialized');
    }

    // Wait for an available worker
    _VipsWorker? worker;
    var attempts = 0;
    const maxAttempts = 100; // 10 seconds max wait
    final waitStartTime = DateTime.now();

    while (worker == null && attempts < maxAttempts) {
      worker = _workers.firstWhere(
        (w) => w.isReady,
        orElse: () => _workers[0], // Fallback to first worker
      );

      if (worker.isBusy) {
        worker = null;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (worker == null) {
      log.warning('[VipsIsolatePool] No worker available after timeout');
      return false;
    }

    // Log if we had to wait for a worker (indicates bottleneck)
    final waitTime = DateTime.now().difference(waitStartTime);
    if (waitTime.inMilliseconds > 100) {
      final busyCount = _workers.where((w) => w.isBusy).length;
      log.warning(
        '[VipsIsolatePool] Waited ${waitTime.inMilliseconds}ms for worker '
        '($busyCount/$poolSize busy) - potential bottleneck',
      );
    }

    // Process resize
    final result = await worker.resizeFile(
      inputPath: inputPath,
      outputPath: outputPath,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    return result;
  }

  /// Get pool status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _initialized,
      'pool_size': poolSize,
      'workers': _workers.length,
      'ready_workers': _workers.where((w) => w.isReady).length,
      'busy_workers': _workers.where((w) => w.isBusy).length,
    };
  }

  /// Dispose the pool and all workers
  Future<void> dispose() async {
    log.info('[VipsIsolatePool] Disposing pool');
    
    for (final worker in _workers) {
      worker.dispose();
    }
    
    _workers.clear();
    _initialized = false;

    try {
      shutdownVips();
    } catch (e) {
      // Ignore errors during shutdown
    }
    
    log.info('[VipsIsolatePool] Pool disposed');
  }
}
