import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

class EditAccountItem extends StatelessWidget {
  final String address;
  final String name;
  final String cryptoType;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EditAccountItem({
    super.key,
    required this.address,
    required this.name,
    required this.cryptoType,
    this.onTap,
    this.onEdit,
    this.onDelete,
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
                    style: AppTypography.body(context).bold.black,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTypography.body(context).black,
                  ),
                ],
              ),
            ),
            Text(
              cryptoType,
              style: AppTypography.body(context).black,
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
