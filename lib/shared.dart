import 'package:autonomy_flutter/screen/app_router.dart';

MemoryValues memoryValues = MemoryValues();

class MemoryValues {
  String? scopedPersona;
  String? viewingSupportThreadIssueID;
  DateTime? inForegroundAt;
  String? currentGroupChatId;
  bool isForeground = true;

  MemoryValues({
    this.scopedPersona,
    this.viewingSupportThreadIssueID,
    this.inForegroundAt,
  });

  MemoryValues copyWith({
    String? scopedPersona,
  }) =>
      MemoryValues(
        scopedPersona: scopedPersona ?? this.scopedPersona,
      );
}

enum HomeNavigatorTab {
  explore,
  menu;

  String get routeName {
    switch (this) {
      case HomeNavigatorTab.explore:
        return AppRouter.explorePage;
      case HomeNavigatorTab.menu:
        return 'Menu';
    }
  }
}
