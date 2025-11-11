const String triggerTokenIndexing = r'''
  mutation triggerTokenIndexing($token_cids: [String!]!) {
    triggerTokenIndexing(token_cids: $token_cids) {
      workflow_id
      run_id
    }
  }
''';

const String triggerOwnerIndexing = r'''
  mutation triggerOwnerIndexing($addresses: [String!]!) {
    triggerOwnerIndexing(addresses: $addresses) {
      workflow_id
      run_id
    }
  }
''';
