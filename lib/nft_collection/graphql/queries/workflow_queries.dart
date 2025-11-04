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
