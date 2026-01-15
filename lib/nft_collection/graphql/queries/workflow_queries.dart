const String workflowStatusQuery = r'''
  query getWorkflowStatus($workflow_id: String!, $run_id: String!) {
    workflowStatus(workflow_id: $workflow_id, run_id: $run_id) {
      workflow_id
      run_id
      status
      start_time
      close_time
      execution_time_ms
    }
  }
''';

const String addressIndexingJobStatusQuery = r'''
  query indexingJob($workflow_id: String!) {
    indexingJob(workflow_id: $workflow_id) {
      workflow_id
      address
      chain
      status
      tokens_processed
      current_min_block
      current_max_block
      started_at
      paused_at
      completed_at
      failed_at
      canceled_at
    }
  }
''';
