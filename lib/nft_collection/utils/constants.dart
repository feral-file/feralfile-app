const indexerTokensPageSize = 50;

enum IndexerAssetTokenSortBy {
  lastActivityTime,
  createdTime;

  String toJson() {
    switch (this) {
      case IndexerAssetTokenSortBy.lastActivityTime:
        return 'lastActivityTime';
      case IndexerAssetTokenSortBy.createdTime:
        return 'createdTime';
    }
  }
}
