const String triggerTokenIndexing = r'''
  mutation triggerTokenIndexing($token_cids: [String!]!) {
    triggerTokenIndexing(token_cids: $token_cids) {
      workflow_id
      run_id
    }
  }
''';

const String triggerOwnerIndexingList = r'''
  mutation triggerOwnerIndexingList($addresses: [String!]!) {
    triggerOwnerIndexingList(addresses: $addresses) {
      address
      workflow_id
    }
  }
''';
