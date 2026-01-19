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
      status
      total_tokens_indexed
      total_tokens_viewable
    }
  }
''';
