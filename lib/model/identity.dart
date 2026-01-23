class IndexerIdentity {
  IndexerIdentity(this.accountNumber, this.blockchain, this.name);

  String accountNumber;
  String blockchain;
  String name;

  DateTime queriedAt = DateTime.now();
}
