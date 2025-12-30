//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/header.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/splitted_banner.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: constant_identifier_names

enum QRScanTab {
  scan,
  ;

  String get routerName {
    switch (this) {
      case scan:
        return AppRouter.scanQRPage;
    }
  }
}

class ScanQRPagePayload {
  final ScannerItem scannerItem;
  final Function? onHandleFinished;
  final bool isFromOnboarding;

  const ScanQRPagePayload({
    required this.scannerItem,
    this.onHandleFinished,
    this.isFromOnboarding = false,
  });
}

class ScanQRPage extends StatefulWidget {
  final ScanQRPagePayload payload;

  const ScanQRPage({required this.payload, super.key});

  @override
  State<ScanQRPage> createState() => ScanQRPageState();
}

class ScanQRPageState extends State<ScanQRPage>
    with RouteAware, TickerProviderStateMixin {
  final GlobalKey<QRScanViewState> _qrScanViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    //There is a conflict with lib qr_code_scanner on Android.
    if (Platform.isIOS) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack));
    }
  }

  Future<void> pauseCamera() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _qrScanViewKey.currentState?.pauseCamera();
  }

  Future<void> resumeCamera() async {
    await _qrScanViewKey.currentState?.resumeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: AppColor.primaryBlack,
          appBar: getDarkEmptyAppBar(Colors.transparent),
          body: Stack(
            children: <Widget>[
              _content(context),
              _header(context),
            ],
          ),
        ),
      );

  Widget _content(BuildContext context) => Column(
        children: [
          Expanded(
            child: QRScanView(
              isFromOnboarding: widget.payload.isFromOnboarding,
              key: _qrScanViewKey,
              scannerItem: widget.payload.scannerItem,
              onHandleFinished: widget.payload.onHandleFinished,
            ),
          ),
        ],
      );

  Widget _header(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).viewPadding.top, left: 20),
          child: HeaderView(
            title: 'scan'.tr(),
            action: Row(
              children: [
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: closeIcon(
                      color: AppColor.white,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didPopNext() {
    super.didPopNext();
    unawaited(resumeCamera());
    if (Platform.isIOS) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack));
    }
  }

  @override
  void didPushNext() {
    super.didPushNext();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values));
    unawaited(pauseCamera());
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values));
    super.dispose();
  }
}

enum ScannerItem {
  ETH_ADDRESS,
  XTZ_ADDRESS,
  GLOBAL,
  CANVAS;

  List<ScannerInstruction> get instructions {
    switch (this) {
      case ETH_ADDRESS:
      case XTZ_ADDRESS:
        return [];
      case GLOBAL:
        return [
          ScannerInstruction.displayFF,
        ];
      case CANVAS:
        return [
          ScannerInstruction.displayFF,
        ];
    }
  }
}

class ScannerInstruction {
  final String name;
  final String detail;
  final Widget? icon;

  const ScannerInstruction({
    required this.name,
    required this.detail,
    this.icon,
  });

  static ScannerInstruction web3Connect = ScannerInstruction(
    name: 'apps'.tr(),
    detail: 'such_as_openSea'.tr(),
  );

  static ScannerInstruction signTransaction = ScannerInstruction(
    name: 'sign_transaction'.tr(),
    detail: 'after_connecting'.tr(),
  );

  static ScannerInstruction displayFF = ScannerInstruction(
    name: 'display_with_ff'.tr(),
    detail: 'on_tv_or_desktop'.tr(),
  );
}

class QRScanView extends StatefulWidget {
  final ScannerItem scannerItem;
  final Function? onHandleFinished;
  final bool isFromOnboarding;
  const QRScanView(
      {required this.scannerItem,
      super.key,
      this.onHandleFinished,
      this.isFromOnboarding = false});

  @override
  State<QRScanView> createState() => QRScanViewState();
}

class QRScanViewState extends State<QRScanView>
    with
        RouteAware,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<QRScanView> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
    useNewCameraSelector: true,
  );
  bool isScanDataError = false;
  bool _isLoading = false;
  bool? _cameraPermission;
  bool _isCameraInitialized = false;
  String? currentCode;
  Timer? _timer;

  StreamSubscription<Object?>? _subscription;

  static const _qrSize = 260.0;
  static const double _topPadding = 144;

  late bool _shouldPop;

  @override
  void initState() {
    super.initState();
    _shouldPop = true;

    WidgetsBinding.instance.addObserver(this);

    // Check permission first, then start camera only if permission is already granted
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    log.info('[Scanner][_initializeCamera] Initializing camera');
    _subscription = _controller.barcodes.listen(_handleBarcode);

    // Listen to controller state changes
    _controller.addListener(_onControllerStateChanged);
    // Check current permission status
    final status = await Permission.camera.status;
    log.info('[Scanner][_initializeCamera] Permission status: $status');

    _controller.start();

    // Request permission if needed (controller will handle state changes via listener)
    if (!status.isGranted && !status.isPermanentlyDenied) {
      await Permission.camera.request();
      log.info('[Scanner][_initializeCamera] Permission requested');
    }
  }

  void _onControllerStateChanged() {
    final isInitialized = _controller.value.isInitialized;
    final isRunning = _controller.value.isRunning;

    log.info(
        '[Scanner] Controller state changed: isInitialized: $isInitialized, isRunning: $isRunning');
    // Only handle permission state changes, ignore other controller state changes
    final controllerHasPermission = _controller.value.hasCameraPermission;
    final currentPermissionState = _cameraPermission;

    // Skip if permission state already matches controller state
    if (controllerHasPermission && currentPermissionState == true) {
      return; // Already granted, no action needed
    }
    if (!controllerHasPermission && currentPermissionState == false) {
      return; // Already denied, no action needed
    }

    log.info(
        '[Scanner] Controller state changed: controllerHasPermission: $controllerHasPermission, currentPermissionState: $currentPermissionState');

    // Handle permission state change
    if (controllerHasPermission && currentPermissionState != true) {
      // Permission was just granted
      unawaited(_onPermissionGranted());
    } else if (!controllerHasPermission && (currentPermissionState ?? true)) {
      // Permission was denied
      _onPermissionDenied();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void didPushNext() {
    super.didPushNext();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
      pauseCamera();
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // App is being terminated - stop camera and cancel subscription
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_controller.stop());
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _onAppInActive();
        return;
      case AppLifecycleState.resumed:
        _onAppActive();
      case AppLifecycleState.inactive:
        _onAppInActive();
    }
  }

  Future<void> _onAppActive() async {
    // Re-initialize permission state when app becomes active (e.g., after granting permission)
    await _initializeCamera();
  }

  void _onAppInActive() {
    // Stop camera and cancel subscription when app becomes inactive
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_controller.value.hasCameraPermission) {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _controller.removeListener(_onControllerStateChanged);
    _timer?.cancel();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCamera({int retryCount = 0}) async {
    try {
      // Verify controller has permission before starting (especially important on Android)
      if (!_controller.value.hasCameraPermission) {
        // Wait a bit for controller state to sync, then retry once
        if (retryCount == 0 && mounted) {
          await Future<void>.delayed(
            Platform.isAndroid
                ? const Duration(milliseconds: 500)
                : const Duration(milliseconds: 200),
          );
          if (mounted && _controller.value.hasCameraPermission) {
            return _startCamera(retryCount: 1);
          }
        }
        log.info(
            '[Scanner] Cannot start camera: permission not granted in controller');
        return;
      }

      await _controller.start();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      log.info('[Scanner] Failed to start camera: $e');
      // Retry once on Android if it's a permission-related error
      if (retryCount == 0 &&
          Platform.isAndroid &&
          mounted &&
          _cameraPermission == true) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted && _controller.value.hasCameraPermission) {
          return _startCamera(retryCount: 1);
        }
      }
    }
  }

  Future<void> resumeCamera() async {
    await _startCamera();
  }

  Future<void> pauseCamera() async {
    await _controller.stop();
  }

  Future<void> _onPermissionGranted() async {
    setState(() {
      _cameraPermission = true;
    });

    // On Android, wait longer for controller state to sync with permission status
    final syncDelay = Platform.isAndroid
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 100);
    final restartDelay = Platform.isAndroid
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 300);

    // Wait for controller to recognize the permission (with retries)
    int attempts = 0;
    while (attempts < 3 && mounted) {
      await Future<void>.delayed(syncDelay);
      if (_controller.value.hasCameraPermission) {
        break;
      }
      attempts++;
    }

    if (mounted) {
      _timer?.cancel();
      _timer = Timer(restartDelay, () async {
        if (mounted) {
          await _startCamera();
        }
      });
    }
  }

  void _onPermissionDenied() {
    if (_cameraPermission ?? true) {
      setState(() {
        _cameraPermission = false;
        _isCameraInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Stack(
      children: [
        if (_cameraPermission == false)
          _noPermissionView(context)
        else ...[
          _qrView(context),
          Positioned.fill(
            bottom: 60,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: _instructionView(context)),
          ),
        ],
        if (_isLoading) ...[
          Center(
            child: CupertinoActivityIndicator(
              color: theme.colorScheme.primary,
              radius: 16,
            ),
          ),
        ],
      ],
    );
  }

  Widget _qrView(BuildContext context) {
    var cutOutBottomOffset =
        MediaQuery.of(context).size.height / 2 - (_qrSize / 2 + _topPadding);
    if (cutOutBottomOffset < 0) {
      cutOutBottomOffset = 0;
    }
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          key: qrKey,
          errorBuilder: (context, error, stack) {
            log.info('[Scanner] Error: $error, stack: $stack');
            if (!_isCameraInitialized || _cameraPermission == false) {
              return const SizedBox.shrink();
            }

            return Positioned(
              left: (MediaQuery.of(context).size.width - _qrSize) / 2,
              top: _topPadding,
              child: SizedBox(
                height: _qrSize,
                width: _qrSize,
                child: Center(
                  child: Text(
                    'invalid_qr_code'.tr(),
                    style: AppTypography.body(context)
                        .bold
                        .black
                        .copyWith(color: Colors.red),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _noPermissionView(BuildContext context) => Stack(
        children: [
          _qrView(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              44,
              _qrSize + _topPadding + 30,
              44,
              120,
            ),
            child: Column(
              children: [
                _instructionViewNoPermission(context),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: PrimaryButton(
                    text: 'open_setting'.tr(
                      namedArgs: {
                        'device': Platform.isAndroid ? 'Device' : 'iOS',
                      },
                    ),
                    onTap: () async {
                      await openAppSettings();
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      );

  Widget _instructionViewNoPermission(BuildContext context) {
    return SplittedBanner(
      headerWidget: Row(
        children: [
          SvgPicture.asset('assets/images/iconController.svg',
              colorFilter: const ColorFilter.mode(
                AppColor.white,
                BlendMode.srcIn,
              )),
          const SizedBox(width: 20),
          Text(
            'allow_camera_permission'.tr(),
            style: AppTypography.body(context).white,
          )
        ],
      ),
      bodyWidget: Text(
        'allow_camera_permission_desc'.tr(),
        style: AppTypography.body(context).white,
      ),
    );
  }

  Widget _instructionView(BuildContext context) {
    if (widget.scannerItem.instructions.isEmpty) {
      return const SizedBox();
    }
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 70),
        child: SingleChildScrollView(
          child: SplittedBanner(
              headerWidget: _instructionHeader(context),
              bodyWidget:
                  _instructionBody(context, widget.scannerItem.instructions)),
        ));
  }

  Widget _instructionHeader(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/icon_scan.svg',
        ),
        const SizedBox(width: 20),
        Expanded(
          child: RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              text: 'scan_qr_code'.tr(),
              children: [
                TextSpan(
                  text: ' ',
                  style: AppTypography.body(context).grey,
                ),
                TextSpan(
                  text: 'in_order_to'.tr(),
                  style: AppTypography.body(context).grey,
                ),
              ],
              style: AppTypography.body(context).white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _instructionBody(
      BuildContext context, List<ScannerInstruction> instructions) {
    return Column(
      children: instructions
          .map(
            (instruction) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instruction.name,
                          style: AppTypography.body(context).bold.white,
                        ),
                        Text(
                          instruction.detail,
                          style: AppTypography.body(context).grey,
                        )
                      ],
                    ),
                  ),
                  instruction.icon ?? const SizedBox(),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _handleBarcode(BarcodeCapture scanData) async {
    if (mounted) {
      if (_isLoading) {
        return;
      }
      if (scanData.barcodes.isEmpty) {
        return;
      }
      if (scanData.barcodes.first.rawValue == currentCode && isScanDataError) {
        return;
      }
      currentCode = scanData.barcodes.first.rawValue;
      final code = scanData.barcodes.first.rawValue!;

      if (DEEP_LINKS.any((prefix) => code.startsWith(prefix))) {
        setState(() {
          _isLoading = true;
        });
        await pauseCamera();
        if (!mounted) {
          return;
        }
        if (_shouldPop) {
          Navigator.pop(context);
        }

        injector<DeeplinkService>().handleDeeplink(
          code,
          delay: const Duration(seconds: 1),
          // ignore: avoid_annotating_with_dynamic
          onFinished: (dynamic object) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              unawaited(resumeCamera());
            }
            widget.onHandleFinished?.call(object);
          },
          isFromOnboarding: widget.isFromOnboarding,
        );
        return;
      } else {
        switch (widget.scannerItem) {
          case ScannerItem.CANVAS:
          // dont need to do anything here,
          // it has been processed in the branch deeplink
          /// handled with deeplink

          case ScannerItem.ETH_ADDRESS:
          case ScannerItem.XTZ_ADDRESS:
            setState(() {
              _isLoading = true;
            });
            await pauseCamera();
            if (!mounted) {
              return;
            }
            if (_shouldPop) {
              Navigator.pop(context, code);
            }
            await Future<void>.delayed(const Duration(milliseconds: 300));
          case ScannerItem.GLOBAL:
            {
              _handleError(code);
            }
        }
        if (mounted) {
          await resumeCamera();
          setState(() {
            _isLoading = false;
          });
        }
        if (!isScanDataError) {
          widget.onHandleFinished?.call();
        }
      }
    }
  }

  void _handleError(String data) {
    setState(() {
      isScanDataError = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          isScanDataError = false;
        });
      }
    });

    log
      ..info('[Scanner][start] scan ${widget.scannerItem}')
      ..info('[Scanner][incorrectScanItem] item: '
          '${data.substring(0, data.length ~/ 2)}');
  }

  @override
  bool get wantKeepAlive => true;
}
