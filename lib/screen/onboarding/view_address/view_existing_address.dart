import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_state.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/au_text_field.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ViewExistingAddress extends StatefulWidget {
  const ViewExistingAddress({required this.payload, super.key});

  final ViewExistingAddressPayload payload;

  @override
  State<ViewExistingAddress> createState() => _ViewExistingAddressState();
}

class _ViewExistingAddressState extends State<ViewExistingAddress> {
  final _controller = TextEditingController();
  Timer? _timer;
  final ViewExistingAddressBloc _bloc = ViewExistingAddressBloc(
    injector<DomainAddressService>(),
    injector<AddressService>(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'add_display_address'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: BlocConsumer<ViewExistingAddressBloc, ViewExistingAddressState>(
        bloc: _bloc,
        listener: (context, state) async {
          if (state is ViewExistingAddressSuccessState) {
            await Navigator.of(context).pushNamed(
              AppRouter.nameLinkedAccountPage,
              arguments: state.walletAddress,
            );
          } else if (state.isError && state.exception != null) {
            await UIHelper.showInfoDialog(
              context,
              state.exception!.message,
              '',
              isDismissible: true,
              closeButton: 'close'.tr(),
              onClose: () {
                Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == AppRouter.homePage ||
                      route.settings.name == AppRouter.homePage ||
                      route.settings.name == AppRouter.walletPage,
                );
              },
            );
          }
        },
        builder: (context, state) => Padding(
          padding: ResponsiveLayout.pageEdgeInsetsWithSubmitButton,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      addTitleSpace(),
                      Text(
                        'enter_a_wallet_address'.tr(),
                        style: theme.textTheme.ppMori400Black14,
                      ),
                      const SizedBox(height: 10),
                      AuTextField(
                        title: '',
                        placeholder: 'enter_address'.tr(),
                        controller: _controller,
                        isError: state.isError,
                        suffix: IconButton(
                          icon: Icon(
                            _controller.text.isEmpty
                                ? AuIcon.scan
                                : AuIcon.close,
                            color: AppColor.secondaryDimGrey,
                          ),
                          onPressed: () async {
                            if (_controller.text.isNotEmpty) {
                              _controller.clear();
                              _bloc.add(AddressChangeEvent(''));
                              return;
                            }
                            dynamic address =
                                await Navigator.of(context).pushNamed(
                              AppRouter.scanQRPage,
                              arguments: const ScanQRPagePayload(
                                scannerItem: ScannerItem.ETH_ADDRESS,
                              ),
                            );
                            if (address != null && address is String) {
                              address = address.replacePrefix('ethereum:', '');
                              _controller.text = address;
                              _bloc.add(AddressChangeEvent(address));
                            }
                          },
                        ),
                        onChanged: _onTextChanged,
                      ),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                enabled: state.address.isNotEmpty && state.isValid,
                isProcessing: state.isAddConnectionLoading,
                text: 'continue'.tr(),
                onTap: () {
                  _bloc.add(AddConnectionEvent());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTextChanged(String value) {
    _timer?.cancel();
    final text = value.trim();
    _timer = Timer(const Duration(milliseconds: 500), () {
      _bloc.add(AddressChangeEvent(text));
    });
  }
}

// payload class
class ViewExistingAddressPayload {
  ViewExistingAddressPayload(this.isOnboarding);

  final bool isOnboarding;
}
