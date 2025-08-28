import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

class ViewAddressItem extends StatelessWidget {
  final String address;
  final String name;
  final String cryptoType;
  final VoidCallback? onTap;

  const ViewAddressItem({
    super.key,
    required this.address,
    required this.name,
    required this.cryptoType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.ppMori700Black16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: Theme.of(context).textTheme.ppMori400Black14,
                  ),
                ],
              ),
            ),
            Text(
              cryptoType,
              style: Theme.of(context).textTheme.ppMori400Black14,
            ),
          ],
        ),
      ),
    );
  }
}
