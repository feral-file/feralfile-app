import 'dart:async';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_changes.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/queries.dart';
import 'package:autonomy_flutter/nft_collection/models/identity.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

abstract class NftIndexerServiceBase {
  Future<List<AssetToken>> getNftTokens(
    QueryListTokensRequest request,
  );

  Future<Identity> getIdentity(QueryIdentityRequest request);

  Future<List<AssetToken>> getAssetTokens(List<DP1Item> items);

  /// Trigger indexing for a list of addresses
  /// Returns the workflow_id and run_id from the indexing operation
  Future<TriggerIndexingResult> indexAddresses(List<String> addresses);

  /// Trigger indexing for a list of token CIDs
  /// Returns the workflow_id and run_id from the indexing operation
  Future<TriggerIndexingResult> indexTokens(List<String> tokenCids);

  /// Get workflow status by workflow ID and run ID
  /// Returns the status of a Temporal workflow execution
  Future<WorkflowStatus> getWorkflowStatus(String workflowId, String runId);

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
    final vars = request.toJson();
    final result = await _client.query(
      doc: identity,
      vars: vars,
    );
    if (result == null) {
      return Identity('', '', '');
    }
    final data = QueryIdentityResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
    return data.identity;
  }

  @override
  Future<List<AssetToken>> getAssetTokens(List<DP1Item> items) async {
    final cids = items.map((item) => item.cid).whereType<String>().toList();
    final assetTokens = await getNftTokens(
      QueryListTokensRequest(tokenCids: cids),
    );
    return List<AssetToken>.from(assetTokens).toList();
  }

  /// Trigger indexing for a list of addresses
  /// This will index all tokens owned by the provided addresses
  ///
  /// [addresses] - List of owner addresses to index
  ///
  /// Returns TriggerIndexingResult with workflow_id and run_id
  @override
  Future<TriggerIndexingResult> indexAddresses(List<String> addresses) async {
    if (addresses.isEmpty) {
      throw ArgumentError('Addresses list cannot be empty');
    }

    final result = await _client.mutate(
      doc: triggerIndexing,
      vars: {
        'addresses': addresses,
      },
      withToken: true,
    );

    if (result == null || result['triggerIndexing'] == null) {
      throw Exception('Failed to trigger indexing for addresses');
    }

    final data = result['triggerIndexing'] as Map<String, dynamic>;
    return TriggerIndexingResult.fromJson(data);
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
      doc: triggerIndexing,
      vars: {
        'token_cids': tokenCids,
      },
      withToken: true,
    );

    if (result == null || result['triggerIndexing'] == null) {
      throw Exception('Failed to trigger indexing for tokens');
    }

    final data = result['triggerIndexing'] as Map<String, dynamic>;
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
