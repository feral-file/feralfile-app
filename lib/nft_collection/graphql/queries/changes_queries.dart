const String getChangesQuery = r'''
  query getChanges(
    $token_cid: [String!]
    $address: [String!]
    $since: String
    $limit: Uint8
    $offset: Uint64
    $order: Order
    $expand: [String!]
  ) {
    changes(
      token_cid: $token_cid
      address: $address
      since: $since
      limit: $limit
      offset: $offset
      order: $order
      expand: $expand
    ) {
      items {
        id
        token_cid
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
    }
  }
''';
