"""
Lambda handler for MCP server.
This allows Bedrock Agents to invoke MCP tools directly via Lambda.
"""

import json
import os
import logging
from http_server import execute_pipeline_logic, get_status_logic, prepare_gitlab_variables

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda handler for MCP server.
    
    Can be invoked by:
    1. Bedrock Agents (via action groups)
    2. Other Lambdas (via Lambda invoke)
    3. API Gateway (for testing)
    """
    
    logger.info(f"MCP Server Lambda invoked")
    logger.info(f"Event: {json.dumps(event)}")
    
    try:
        # Determine invocation source
        if 'actionGroup' in event:
            # Invoked by Bedrock Agent (action group)
            return handle_bedrock_invocation(event, context)
        elif 'httpMethod' in event:
            # Invoked via API Gateway
            return handle_api_gateway_invocation(event, context)
        else:
            # Direct Lambda invocation
            return handle_direct_invocation(event, context)
    
    except Exception as e:
        logger.error(f"Error in MCP server: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def handle_bedrock_invocation(event, context):
    """
    Handle invocation from Bedrock Agent action group.
    
    Event structure from Bedrock:
    {
        "actionGroup": "mcp-pipeline-tools",
        "apiPath": "/mcp/execute-bootstrap",
        "httpMethod": "POST",
        "requestBody": {
            "content": {
                "application/json": "{...}"
            }
        }
    }
    """
    
    action = event.get('actionGroup', '')
    api_path = event.get('apiPath', '')
    request_body = event.get('requestBody', {})
    
    logger.info(f"Bedrock invocation - Action: {action}, Path: {api_path}")
    
    # Parse request body
    params = {}
    if request_body and 'content' in request_body:
        body_content = request_body['content']
        if isinstance(body_content, dict) and 'application/json' in body_content:
            params = json.loads(body_content['application/json'])
    
    # Route to appropriate handler
    if api_path == '/mcp/execute-bootstrap':
        result = execute_pipeline('bootstrap', params)
    elif api_path == '/mcp/execute-compute':
        result = execute_pipeline('compute', params)
    elif api_path == '/mcp/execute-app':
        result = execute_pipeline('app', params)
    elif api_path == '/mcp/get-status':
        result = get_status(params)
    else:
        result = {'error': f'Unknown API path: {api_path}'}
    
    # Return in Bedrock action group format
    return {
        'messageVersion': '1.0',
        'response': {
            'actionGroup': action,
            'apiPath': api_path,
            'httpMethod': event.get('httpMethod', 'POST'),
            'httpStatusCode': 200,
            'responseBody': {
                'application/json': {
                    'body': json.dumps(result)
                }
            }
        }
    }

def handle_api_gateway_invocation(event, context):
    """Handle invocation via API Gateway (for testing)"""
    
    path = event.get('path', '')
    method = event.get('httpMethod', '')
    body = json.loads(event.get('body', '{}'))
    
    logger.info(f"API Gateway invocation - Method: {method}, Path: {path}")
    
    if path == '/execute' and method == 'POST':
        result = execute_pipeline(
            body.get('pipeline_type'),
            body
        )
    elif path.startswith('/status/') and method == 'GET':
        execution_id = path.split('/')[-1]
        result = get_status({'execution_id': execution_id})
    else:
        result = {'error': 'Unknown endpoint'}
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(result)
    }

def handle_direct_invocation(event, context):
    """Handle direct Lambda invocation"""
    
    logger.info("Direct Lambda invocation")
    
    action = event.get('action', 'execute')
    
    if action == 'execute':
        result = execute_pipeline(
            event.get('pipeline_type'),
            event
        )
    elif action == 'status':
        result = get_status(event)
    else:
        result = {'error': f'Unknown action: {action}'}
    
    return result

def execute_pipeline(pipeline_type, params):
    """
    Execute a pipeline.
    
    This is the core MCP tool implementation.
    """
    
    import uuid
    from datetime import datetime
    import boto3
    
    execution_id = str(uuid.uuid4())
    
    logger.info("=" * 80)
    logger.info("PIPELINE EXECUTION REQUEST")
    logger.info("=" * 80)
    logger.info(f"Execution ID: {execution_id}")
    logger.info(f"Pipeline Type: {pipeline_type}")
    logger.info(f"Environment: {params.get('environment')}")
    logger.info(f"Tenant ID: {params.get('tenant_id')}")
    logger.info(f"Parameters: {params.get('parameters', {})}")
    logger.info("=" * 80)
    
    # Prepare GitLab variables
    gitlab_variables = prepare_gitlab_variables_from_params(pipeline_type, params)
    
    logger.info("GitLab Pipeline Variables:")
    for key, value in gitlab_variables.items():
        logger.info(f"  {key}: {value}")
    
    # Trigger GitLab pipeline (STUBBED)
    gitlab_pipeline_id = trigger_gitlab_pipeline_stub(pipeline_type, gitlab_variables)
    
    # Create execution record
    execution = {
        "execution_id": execution_id,
        "gitlab_pipeline_id": gitlab_pipeline_id,
        "pipeline_type": pipeline_type,
        "environment": params.get('environment'),
        "tenant_id": params.get('tenant_id'),
        "status": "completed",  # STUB: Would be "running" in real implementation
        "started_at": datetime.now().isoformat(),
        "completed_at": datetime.now().isoformat(),  # STUB
        "parameters": params.get('parameters', {}),
        "steps": get_pipeline_steps(pipeline_type)
    }
    
    # Store in DynamoDB
    store_in_dynamodb(execution)
    
    logger.info(f"Pipeline execution completed: {execution_id}")
    logger.info("=" * 80)
    
    return execution

def get_status(params):
    """Get pipeline execution status"""
    
    execution_id = params.get('execution_id')
    
    logger.info(f"Status check for execution: {execution_id}")
    
    # In real implementation, query DynamoDB or GitLab API
    # For now, return stub
    return {
        "execution_id": execution_id,
        "status": "completed",
        "message": "Pipeline execution completed successfully"
    }

def prepare_gitlab_variables_from_params(pipeline_type, params):
    """Prepare GitLab variables from parameters"""
    
    variables = {
        "PIPELINE_TYPE": pipeline_type,
        "ENVIRONMENT": params.get('environment', 'dev'),
        "EXECUTION_ID": str(uuid.uuid4())
    }
    
    if params.get('tenant_id'):
        variables["TENANT_ID"] = params['tenant_id']
    
    # Add pipeline-specific parameters
    if pipeline_type == "bootstrap":
        if params.get('region'):
            variables["AWS_REGION"] = params['region']
    elif pipeline_type == "compute":
        if params.get('instance_type'):
            variables["INSTANCE_TYPE"] = params['instance_type']
        if params.get('instance_count'):
            variables["INSTANCE_COUNT"] = str(params['instance_count'])
    elif pipeline_type == "app":
        if params.get('app_name'):
            variables["APP_NAME"] = params['app_name']
        if params.get('app_version'):
            variables["APP_VERSION"] = params['app_version']
    
    return variables

def trigger_gitlab_pipeline_stub(pipeline_type, variables):
    """
    STUB: Trigger GitLab pipeline.
    
    In real implementation:
    import requests
    response = requests.post(
        f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/pipeline",
        headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
        json={"ref": "main", "variables": [...]}
    )
    return response.json()["id"]
    """
    
    import uuid
    
    fake_pipeline_id = f"stub-{uuid.uuid4().hex[:8]}"
    
    logger.warning("=" * 80)
    logger.warning("STUBBED GITLAB API CALL")
    logger.warning("=" * 80)
    logger.warning(f"Would trigger GitLab pipeline with variables:")
    for key, value in variables.items():
        logger.warning(f"  {key}: {value}")
    logger.warning(f"Returning fake pipeline ID: {fake_pipeline_id}")
    logger.warning("=" * 80)
    
    return fake_pipeline_id

def get_pipeline_steps(pipeline_type):
    """Get expected steps for a pipeline type"""
    
    steps_map = {
        "bootstrap": [
            {"name": "Validate prerequisites", "status": "completed"},
            {"name": "Create VPC", "status": "completed"},
            {"name": "Create Subnets", "status": "completed"},
            {"name": "Configure NAT Gateways", "status": "completed"},
            {"name": "Configure Route Tables", "status": "completed"},
            {"name": "Configure ACLs", "status": "completed"},
            {"name": "Create Security Groups", "status": "completed"}
        ],
        "compute": [
            {"name": "Validate prerequisites", "status": "completed"},
            {"name": "Select AMI", "status": "completed"},
            {"name": "Launch EC2 instances", "status": "completed"},
            {"name": "Configure security groups", "status": "completed"},
            {"name": "Attach IAM roles", "status": "completed"},
            {"name": "Configure monitoring", "status": "completed"}
        ],
        "app": [
            {"name": "Download application artifacts", "status": "completed"},
            {"name": "Copy to EC2 instances", "status": "completed"},
            {"name": "Install dependencies", "status": "completed"},
            {"name": "Configure application", "status": "completed"},
            {"name": "Start services", "status": "completed"},
            {"name": "Run health checks", "status": "completed"}
        ]
    }
    
    return steps_map.get(pipeline_type, [])

def store_in_dynamodb(execution):
    """Store execution in DynamoDB"""
    
    import boto3
    from datetime import datetime
    
    dynamodb = boto3.resource('dynamodb')
    table_name = os.environ.get('MEMORY_TABLE_NAME')
    
    if not table_name:
        logger.warning("MEMORY_TABLE_NAME not set, skipping DynamoDB storage")
        return
    
    table = dynamodb.Table(table_name)
    
    timestamp = int(datetime.now().timestamp())
    
    item = {
        'session_id': execution['execution_id'],
        'timestamp': timestamp,
        'environment': execution.get('environment', 'unknown'),
        'tenant_id': execution.get('tenant_id', 'N/A'),
        'pipeline_type': execution['pipeline_type'],
        'status': execution['status'],
        'details': json.dumps(execution),
        'ttl': timestamp + (30 * 24 * 60 * 60)  # 30 days
    }
    
    table.put_item(Item=item)
    logger.info(f"Stored execution in DynamoDB: {execution['execution_id']}")

# For compatibility with http_server.py imports
import uuid
