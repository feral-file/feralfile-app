import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

final ffCastButtonComponent = WidgetbookComponent(
  name: 'FFCastButton',
  useCases: [
    WidgetbookUseCase(
      name: 'default',
      builder: useCaseFFCastButton,
    ),
  ],
);

Widget useCaseFFCastButton(BuildContext context) {
  return FFCastButton(
    type: context.knobs.stringOrNull(label: 'Type'),
    text: context.knobs.stringOrNull(label: 'Text'),
    shouldCheckSubscription:
        context.knobs.boolean(label: 'Should check subscription'),
    onTap: () {},
  );
}
