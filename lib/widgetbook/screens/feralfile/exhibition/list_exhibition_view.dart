import 'package:autonomy_flutter/screen/feralfile_home/list_exhibition_view.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_exhibition.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookUseCase listExhibitionView() {
  return WidgetbookUseCase(
    name: 'List Exhibition View',
    builder: (context) => ListExhibitionView(
      exhibitions: MockExhibitionData.listExhibition,
    ),
  );
}
