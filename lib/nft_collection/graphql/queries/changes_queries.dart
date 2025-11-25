const String getChangesQuery = r'''
  query getChanges(
    $token_cids: [String!]
    $addresses: [String!]
    $since: String
    $limit: Uint8
    $anchor: Uint64
    $offset: Uint64
    $order: Order
    $expand: [String!]
  ) {
    changes(
      token_cids: $token_cids
      addresses: $addresses
      since: $since
      limit: $limit
      anchor: $anchor
      offset: $offset
      order: $order
      expand: $expand
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
