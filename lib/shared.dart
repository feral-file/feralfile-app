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
