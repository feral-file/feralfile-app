import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/SendButton.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:flutter/material.dart';

class ScanButton extends StatelessWidget {
  const ScanButton({super.key, this.onScanDone});
  final void Function(String?)? onScanDone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Icon(
        AuIcon.scan,
        color: AppColor.white,
        size: SendButtonTokens.size.toDouble(),
      ),
      onTap: () async {
        dynamic res = await injector<NavigationService>().navigateTo(
          AppRouter.scanQRPage,
          arguments: const ScanQRPagePayload(
            scannerItem: ScannerItem.ETH_ADDRESS,
          ),
        );
        final text = res as String?;
        if (text == null) return;
        onScanDone?.call(text);
      },
    );
  }
}
