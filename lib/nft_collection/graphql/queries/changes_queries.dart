const String getChangesQuery = r'''
  query getChanges(
    $token_cids: [String!]
    $addresses: [String!]
    $limit: Uint8
    $anchor: Uint64
  ) {
    changes(
      token_cids: $token_cids
      addresses: $addresses
      limit: $limit
      anchor: $anchor
    ) {
      items {
        id
        subject_type
        subject_id
        changed_at
        meta
        subject
        created_at
        updated_at
      }
      offset
      total
      next_anchor
    }
  }
''';
