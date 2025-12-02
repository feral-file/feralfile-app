import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/widgets.dart';

class NoPairingDeviceDialog extends StatelessWidget {
  const NoPairingDeviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Image.asset('assets/images/no_pairing_device.png'),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Meet FF1'),
                      Column(
                        children: [
                          Text('The art computer by Feral File.'),
                          Text('Made to play digital art on any screen.'),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      PrimaryButton(
                        text: 'Connect to FF1',
                        onTap: () {},
                      ),
                      const Text('Shipping in November, 2025'),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
