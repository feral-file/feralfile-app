import 'dart:async';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_changes.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/queries.dart';
import 'package:autonomy_flutter/nft_collection/models/identity.dart';

abstract class NftIndexerServiceBase {
  Future<List<AssetToken>> getNftTokens(
    QueryListTokensRequest request,
  );

  Future<Identity> getIdentity(QueryIdentityRequest request);

  /// Trigger indexing for a list of token CIDs
  /// Returns the workflow_id and run_id from the indexing operation
  Future<TriggerIndexingResult> indexTokens(List<String> tokenCids);

  /// Get workflow status by workflow ID and run ID
  /// Returns the status of a Temporal workflow execution
  Future<WorkflowStatus> getWorkflowStatus(String workflowId, String runId);

  /// Index a list of addresses and return per-address workflowIds
  /// Returns a list of AddressIndexingResult with address and workflowId pairs
  Future<List<AddressIndexingResult>> indexAddressesList(
      List<String> addresses);

  /// Get address indexing job status by workflowId (no runId needed)
  /// Returns AddressIndexingJobResponse with detailed status information
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
      String workflowId);

  /// Get changes with filters
  /// Returns a paginated list of changes
  Future<ChangeList> getChanges(QueryChangesRequest request);

  /// Get a single token by CID
  Future<AssetToken?> getTokenByCid(
    QueryGetTokenByCidRequest request,
  );
}

class NftIndexerService implements NftIndexerServiceBase {
  NftIndexerService(this._client);

  final IndexerClient _client;

  /*
  getNftTokens
  params: QueryListTokensRequest
  return: List<AssetToken>
  description: Get the list of asset tokens from the indexer
  */
  @override
  Future<List<AssetToken>> getNftTokens(QueryListTokensRequest request) async {
    final vars = request.toJson();
    final result = await _client.query(
      doc: getTokens,
      vars: vars,
    );
    if (result == null) {
      return [];
    }
    final data = QueryListTokensResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
      AssetToken.fromGraphQL,
    );
    final assetTokens = data.tokens;

    return assetTokens;
  }

  @override
  Future<Identity> getIdentity(QueryIdentityRequest request) async {
    return Identity('', '', '');
  }

  /// Trigger indexing for a list of token CIDs
  /// This will index the specified tokens by their CIDs
  ///
  /// [tokenCids] - List of token CIDs to index
  ///
  /// Returns TriggerIndexingResult with workflow_id and run_id
  @override
  Future<TriggerIndexingResult> indexTokens(List<String> tokenCids) async {
    if (tokenCids.isEmpty) {
      throw ArgumentError('Token CIDs list cannot be empty');
    }

    final result = await _client.mutate(
      doc: triggerTokenIndexing,
      vars: {
        'token_cids': tokenCids,
      },
      withToken: false,
    );

    if (result == null || result['triggerTokenIndexing'] == null) {
      throw Exception('Failed to trigger indexing for tokens');
    }

    final data = result['triggerTokenIndexing'] as Map<String, dynamic>;
    return TriggerIndexingResult.fromJson(data);
  }

  /// Get workflow status by workflow ID and run ID
  /// This retrieves the status of a Temporal workflow execution
  ///
  /// [workflowId] - The workflow ID
  /// [runId] - The run ID
  ///
  /// Returns WorkflowStatus with status, start_time, close_time, and execution_time_ms
  @override
  Future<WorkflowStatus> getWorkflowStatus(
      String workflowId, String runId) async {
    if (workflowId.isEmpty || runId.isEmpty) {
      throw ArgumentError('Workflow ID and Run ID cannot be empty');
    }

    final result = await _client.query(
      doc: workflowStatusQuery,
      vars: {
        'workflow_id': workflowId,
        'run_id': runId,
      },
    );

    if (result == null || result['workflowStatus'] == null) {
      throw Exception('Failed to get workflow status');
    }

    final data = result['workflowStatus'] as Map<String, dynamic>;
    return WorkflowStatus.fromJson(data);
  }

  /// Index a list of addresses and return per-address workflowIds
  /// This will index all tokens owned by the provided addresses
  ///
  /// [addresses] - List of owner addresses to index
  ///
  /// Returns a list of AddressIndexingResult with address and workflowId pairs
  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
      List<String> addresses) async {
    // final fakeResults = addresses
    //     .map((address) => AddressIndexingResult(
    //         address: address, workflowId: 'fake_workflow_id'))
    //     .toList();
    // return fakeResults;
    if (addresses.isEmpty) {
      throw ArgumentError('Addresses list cannot be empty');
    }

    try {
      final result = await _client.mutate(
        doc: triggerOwnerIndexingList,
        vars: {
          'addresses': addresses,
        },
        withToken: true,
      );

      if (result == null) {
        throw Exception(
            'Received null response when triggering indexing for addresses ${addresses.join(', ')}');
      }

      if (result['triggerAddressIndexing'] == null) {
        throw Exception(
            'Response missing triggerAddressIndexing field. Response keys: ${result.keys.join(', ')}. Addresses: ${addresses.join(', ')}');
      }

      final triggerResult =
          result['triggerAddressIndexing'] as Map<String, dynamic>?;
      if (triggerResult == null) {
        throw Exception(
            'triggerAddressIndexing is null in response. Addresses: ${addresses.join(', ')}');
      }

      final jobs = triggerResult['jobs'] as List<dynamic>?;

      if (jobs == null) {
        throw Exception(
            'Invalid response format: missing jobs array. Response structure: ${triggerResult.keys.join(', ')}. Addresses: ${addresses.join(', ')}');
      }

      return jobs
          .map((item) => AddressIndexingResult.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      // Re-throw with more context about the mutation
      if (e.toString().contains('FormatException') ||
          e.toString().contains('Unexpected character')) {
        throw Exception(
            'Server returned invalid response format (not JSON) when triggering address indexing. '
            'This may indicate a server error or authentication issue. '
            'Addresses: ${addresses.join(', ')}. '
            'Original error: $e');
      }
      // Re-throw other exceptions as-is
      rethrow;
    }
  }

  /// Get address indexing job status by workflowId (no runId needed)
  /// This retrieves the detailed status of an address indexing job
  ///
  /// [workflowId] - The workflow ID
  ///
  /// Returns AddressIndexingJobResponse with status, tokens_processed, block ranges, etc.
  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
      String workflowId) async {
    // final fakeResult = AddressIndexingJobResponse(
    //     workflowId: workflowId,
    //     address: 'fake_address',
    //     chain: 'fake_chain',
    //     status: IndexingJobStatus.failed,
    //     tokensProcessed: Random().nextInt(1000),
    //     startedAt: DateTime.now());
    // return fakeResult;
    if (workflowId.isEmpty) {
      throw ArgumentError('Workflow ID cannot be empty');
    }

    final result = await _client.query(
      doc: addressIndexingJobStatusQuery,
      vars: {
        'workflow_id': workflowId,
      },
    );

    if (result == null || result['indexingJob'] == null) {
      throw Exception('Failed to get address indexing job status');
    }

    final data = result['indexingJob'] as Map<String, dynamic>;
    return AddressIndexingJobResponse.fromJson(data);
  }

  /// Get changes with filters
  /// This retrieves a paginated list of changes from the change journal
  ///
  /// [request] - QueryChangesRequest with filters and pagination
  ///
  /// Returns ChangeList with items, offset, and total
  @override
  Future<ChangeList> getChanges(QueryChangesRequest request) async {
    final vars = request.toJson();
    final result = await _client.query(
      doc: getChangesQuery,
      vars: vars,
    );

    if (result == null || result['changes'] == null) {
      throw Exception('Failed to get changes');
    }

    final data = result['changes'] as Map<String, dynamic>;
    return ChangeList.fromJson(data);
  }

  /// Get a single token by CID
  @override
  Future<AssetToken?> getTokenByCid(
    QueryGetTokenByCidRequest request,
  ) async {
    final result = await _client.query(
      doc: getTokenByCidQuery,
      vars: request.toJson(),
    );

    if (result == null) {
      return null;
    }

    final tokenJson = result['token'];
    if (tokenJson == null) {
      return null;
    }

    return AssetToken.fromGraphQL(
      Map<String, dynamic>.from(tokenJson as Map),
    );
  }

  /// Get owners and provenance events for a token by CID
  /// This method only returns owners and provenance events, not the full token
  ///
  /// [cid] - Token CID
  /// [ownersLimit] - Maximum number of owners to return (default: 255)
  /// [ownersOffset] - Offset for owners pagination (default: 0)
  /// [provenanceEventsLimit] - Maximum number of provenance events to return (default: 255)
  /// [provenanceEventsOffset] - Offset for provenance events pagination (default: 0)
  ///
  /// Returns TokenOwnersAndProvenance with owners and provenance_events including total and offset
  Future<TokenOwnersAndProvenance?> getOwnerAndProvenanceOfToken({
    required String cid,
    int ownersLimit = 255,
    int ownersOffset = 0,
    int provenanceEventsLimit = 255,
    int provenanceEventsOffset = 0,
    Order provenanceEventsOrder = Order.desc,
  }) async {
    final result = await _client.query(
      doc: getTokenWithOwnersAndProvenanceQuery,
      vars: {
        'cid': cid,
        'owners_limit': ownersLimit,
        'owners_offset': ownersOffset,
        'provenance_events_limit': provenanceEventsLimit,
        'provenance_events_offset': provenanceEventsOffset,
        'provenance_events_order': provenanceEventsOrder.toJson(),
      },
    );

    if (result == null) {
      return null;
    }

    final tokenJson = result['token'];
    if (tokenJson == null) {
      return null;
    }

    final ownersJson = tokenJson['owners'];
    final provenanceEventsJson = tokenJson['provenance_events'];

    return TokenOwnersAndProvenance(
      owners: ownersJson != null
          ? PaginatedOwners.fromJson(
              Map<String, dynamic>.from(ownersJson as Map),
            )
          : null,
      provenanceEvents: provenanceEventsJson != null
          ? PaginatedProvenanceEvents.fromJson(
              Map<String, dynamic>.from(provenanceEventsJson as Map),
            )
          : null,
    );
  }
}

/// Response containing only owners and provenance events for a token
class TokenOwnersAndProvenance {
  TokenOwnersAndProvenance({
    this.owners,
    this.provenanceEvents,
  });

  final PaginatedOwners? owners;
  final PaginatedProvenanceEvents? provenanceEvents;
}

/// Result from triggering indexing operation
class TriggerIndexingResult {
  TriggerIndexingResult({
    required this.workflowId,
    required this.runId,
  });

  final String workflowId;
  final String runId;

  factory TriggerIndexingResult.fromJson(Map<String, dynamic> json) =>
      TriggerIndexingResult(
        workflowId: json['workflow_id'] as String,
        runId: json['run_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'workflow_id': workflowId,
        'run_id': runId,
      };
}

/// Workflow execution status enum
/// Based on Temporal workflow execution status values
enum WorkflowExecutionStatus {
  running,
  completed,
  failed,
  canceled,
  terminated,
  timedOut,
  continuedAsNew,
  unknown;

  String toJson() {
    switch (this) {
      case WorkflowExecutionStatus.running:
        return 'RUNNING';
      case WorkflowExecutionStatus.completed:
        return 'COMPLETED';
      case WorkflowExecutionStatus.failed:
        return 'FAILED';
      case WorkflowExecutionStatus.canceled:
        return 'CANCELED';
      case WorkflowExecutionStatus.terminated:
        return 'TERMINATED';
      case WorkflowExecutionStatus.timedOut:
        return 'TIMED_OUT';
      case WorkflowExecutionStatus.continuedAsNew:
        return 'CONTINUED_AS_NEW';
      case WorkflowExecutionStatus.unknown:
        return 'UNKNOWN';
    }
  }

  static WorkflowExecutionStatus fromJson(String? value) {
    if (value == null) return WorkflowExecutionStatus.unknown;
    // Handle both formats: "RUNNING" and "WORKFLOW_EXECUTION_STATUS_RUNNING"
    final normalized = value.toUpperCase().replaceFirst(
          'WORKFLOW_EXECUTION_STATUS_',
          '',
        );
    switch (normalized) {
      case 'RUNNING':
        return WorkflowExecutionStatus.running;
      case 'COMPLETED':
        return WorkflowExecutionStatus.completed;
      case 'FAILED':
        return WorkflowExecutionStatus.failed;
      case 'CANCELED':
        return WorkflowExecutionStatus.canceled;
      case 'TERMINATED':
        return WorkflowExecutionStatus.terminated;
      case 'TIMED_OUT':
      case 'TIMEDOUT': // Handle variant without underscore
        return WorkflowExecutionStatus.timedOut;
      case 'CONTINUED_AS_NEW':
      case 'CONTINUEDASNEW': // Handle variant without underscores
        return WorkflowExecutionStatus.continuedAsNew;
      default:
        return WorkflowExecutionStatus.unknown;
    }
  }

  bool get isDone {
    return this == WorkflowExecutionStatus.completed ||
        this == WorkflowExecutionStatus.failed ||
        this == WorkflowExecutionStatus.canceled ||
        this == WorkflowExecutionStatus.terminated ||
        this == WorkflowExecutionStatus.timedOut;
  }

  bool get isSuccess {
    return this == WorkflowExecutionStatus.completed;
  }

  bool get isRunning {
    return this == WorkflowExecutionStatus.running;
  }

  bool get isFailed {
    return this == WorkflowExecutionStatus.failed;
  }

  bool get isCanceled {
    return this == WorkflowExecutionStatus.canceled;
  }

  bool get isTerminated {
    return this == WorkflowExecutionStatus.terminated;
  }

  bool get isTimedOut {
    return this == WorkflowExecutionStatus.timedOut;
  }
}

/// Workflow status information from Temporal workflow execution
class WorkflowStatus {
  WorkflowStatus({
    required this.workflowId,
    required this.runId,
    required this.status,
    this.startTime,
    this.closeTime,
    this.executionTimeMs,
  });

  final String workflowId;
  final String runId;
  final WorkflowExecutionStatus status;
  final DateTime? startTime;
  final DateTime? closeTime;
  final int? executionTimeMs;

  factory WorkflowStatus.fromJson(Map<String, dynamic> json) => WorkflowStatus(
        workflowId: json['workflow_id'] as String,
        runId: json['run_id'] as String,
        status: WorkflowExecutionStatus.fromJson(json['status'] as String?),
        startTime: json['start_time'] != null
            ? DateTime.tryParse(json['start_time'] as String)
            : null,
        closeTime: json['close_time'] != null
            ? DateTime.tryParse(json['close_time'] as String)
            : null,
        executionTimeMs: json['execution_time_ms'] != null
            ? int.tryParse(json['execution_time_ms'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'workflow_id': workflowId,
        'run_id': runId,
        'status': status.toJson(),
        'start_time': startTime?.toIso8601String(),
        'close_time': closeTime?.toIso8601String(),
        'execution_time_ms': executionTimeMs,
      };
}

/// Indexing job status enum
/// Based on new indexer API status values
enum IndexingJobStatus {
  running,
  paused,
  failed,
  completed,
  canceled;

  String toJson() {
    switch (this) {
      case IndexingJobStatus.running:
        return 'running';
      case IndexingJobStatus.paused:
        return 'paused';
      case IndexingJobStatus.failed:
        return 'failed';
      case IndexingJobStatus.completed:
        return 'completed';
      case IndexingJobStatus.canceled:
        return 'canceled';
    }
  }

  static IndexingJobStatus fromJson(String? value) {
    if (value == null) return IndexingJobStatus.running;
    switch (value.toLowerCase()) {
      case 'running':
        return IndexingJobStatus.running;
      case 'paused':
        return IndexingJobStatus.paused;
      case 'failed':
        return IndexingJobStatus.failed;
      case 'completed':
        return IndexingJobStatus.completed;
      case 'canceled':
        return IndexingJobStatus.canceled;
      default:
        return IndexingJobStatus.running;
    }
  }

  bool get isDone {
    return this == IndexingJobStatus.completed ||
        this == IndexingJobStatus.failed ||
        this == IndexingJobStatus.canceled;
  }

  bool get isSuccess {
    return this == IndexingJobStatus.completed;
  }

  bool get isRunning {
    return this == IndexingJobStatus.running;
  }

  bool get isPaused {
    return this == IndexingJobStatus.paused;
  }

  bool get isFailed {
    return this == IndexingJobStatus.failed;
  }

  bool get isCanceled {
    return this == IndexingJobStatus.canceled;
  }
}

/// Address indexing job response from new indexer API
/// Matches the Go struct AddressIndexingJobResponse
class AddressIndexingJobResponse {
  AddressIndexingJobResponse({
    required this.workflowId,
    required this.address,
    required this.chain,
    required this.status,
    required this.tokensProcessed,
    required this.startedAt,
    this.currentMinBlock,
    this.currentMaxBlock,
    this.pausedAt,
    this.completedAt,
    this.failedAt,
    this.canceledAt,
  });

  final String workflowId;
  final String address;
  final String chain;
  final IndexingJobStatus status;
  final int tokensProcessed;
  final int? currentMinBlock;
  final int? currentMaxBlock;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? canceledAt;

  factory AddressIndexingJobResponse.fromJson(Map<String, dynamic> json) =>
      AddressIndexingJobResponse(
        workflowId: json['workflow_id'] as String,
        address: json['address'] as String,
        chain: json['chain'] as String,
        status: IndexingJobStatus.fromJson(json['status'] as String?),
        tokensProcessed: json['tokens_processed'] as int? ?? 0,
        currentMinBlock: json['current_min_block'] != null
            ? int.tryParse(json['current_min_block'].toString())
            : null,
        currentMaxBlock: json['current_max_block'] != null
            ? int.tryParse(json['current_max_block'].toString())
            : null,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : DateTime.now(),
        pausedAt: json['paused_at'] != null
            ? DateTime.tryParse(json['paused_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
        failedAt: json['failed_at'] != null
            ? DateTime.tryParse(json['failed_at'] as String)
            : null,
        canceledAt: json['canceled_at'] != null
            ? DateTime.tryParse(json['canceled_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'workflow_id': workflowId,
        'address': address,
        'chain': chain,
        'status': status.toJson(),
        'tokens_processed': tokensProcessed,
        'current_min_block': currentMinBlock,
        'current_max_block': currentMaxBlock,
        'started_at': startedAt.toIso8601String(),
        'paused_at': pausedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'failed_at': failedAt?.toIso8601String(),
        'canceled_at': canceledAt?.toIso8601String(),
      };
}

/// Result from batch address indexing operation
/// Contains address and workflowId pair
class AddressIndexingResult {
  AddressIndexingResult({
    required this.address,
    required this.workflowId,
  });

  final String address;
  final String workflowId;

  factory AddressIndexingResult.fromJson(Map<String, dynamic> json) =>
      AddressIndexingResult(
        address: json['address'] as String,
        workflowId: json['workflow_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'address': address,
        'workflow_id': workflowId,
      };
}
