const String triggerIndexing = r'''
  mutation triggerIndexing($token_cids: [String!], $addresses: [String!]) {
    triggerIndexing(token_cids: $token_cids, addresses: $addresses) {
      workflow_id
      run_id
    }
  }
''';
