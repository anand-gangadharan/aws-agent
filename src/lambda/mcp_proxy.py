"""
Lambda function that proxies MCP tool calls from Bedrock agents.
This is where the actual pipeline execution happens via the MCP server.
"""

import json
import os
import boto3
import requests
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
memory_table = dynamodb.Table(os.environ['MEMORY_TABLE_NAME'])
mcp_server_url = os.environ.get('MCP_SERVER_URL', 'http://localhost:8000')

def handler(event, context):
    """
    Lambda handler that proxies MCP tool calls.
    Bedrock agents call this when they decide to use their MCP tools.
    """
    
    print(f"Event: {json.dumps(event)}")
    
    action = event.get('actionGroup', '')
    api_path = event.get('apiPath', '')
    request_body = event.get('requestBody', {})
    
    # Parse request body
    params = {}
    if request_body and 'content' in request_body:
        body_content = request_body['content']
        if isinstance(body_content, dict) and 'application/json' in body_content:
            params = json.loads(body_content['application/json'])
    
    try:
        # Route to appropriate MCP tool based on API path
        if api_path == '/mcp/execute-bootstrap':
            result = execute_mcp_tool('execute_bootstrap_pipeline', params)
        elif api_path == '/mcp/execute-compute':
            result = execute_mcp_tool('execute_compute_pipeline', params)
        elif api_path == '/mcp/execute-app':
            result = execute_mcp_tool('execute_app_pipeline', params)
        elif api_path == '/mcp/get-status':
            result = execute_mcp_tool('get_pipeline_status', params)
        else:
            result = {'error': f'Unknown API path: {api_path}'}
        
        # Store execution in memory if successful
        if 'execution_id' in result and 'error' not in result:
            store_in_memory(result)
        
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
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': event.get('httpMethod', 'POST'),
                'httpStatusCode': 500,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({'error': str(e)})
                    }
                }
            }
        }

def execute_mcp_tool(tool_name, params):
    """
    Execute an MCP tool by calling the MCP server.
    This is the actual pipeline execution.
    """
    
    print(f"Executing MCP tool: {tool_name} with params: {params}")
    
    # Map tool names to HTTP endpoints
    if tool_name == 'execute_bootstrap_pipeline':
        pipeline_type = 'bootstrap'
    elif tool_name == 'execute_compute_pipeline':
        pipeline_type = 'compute'
    elif tool_name == 'execute_app_pipeline':
        pipeline_type = 'app'
    elif tool_name == 'get_pipeline_status':
        # Status check
        execution_id = params.get('execution_id')
        response = requests.get(
            f"{mcp_server_url}/status/{execution_id}",
            timeout=10
        )
        return response.json()
    else:
        return {'error': f'Unknown tool: {tool_name}'}
    
    # Execute pipeline via MCP server
    response = requests.post(
        f"{mcp_server_url}/execute",
        json={
            'pipeline_type': pipeline_type,
            'environment': params.get('environment'),
            'tenant_id': params.get('tenant_id'),
            'parameters': {
                'region': params.get('region'),
                'instance_type': params.get('instance_type'),
                'instance_count': params.get('instance_count'),
                'app_name': params.get('app_name'),
                'app_version': params.get('app_version')
            }
        },
        timeout=60
    )
    
    result = response.json()
    print(f"MCP tool result: {json.dumps(result)}")
    
    return result

def store_in_memory(execution_result):
    """
    Store pipeline execution in DynamoDB for future reference.
    This enables the orchestrator to check deployment history.
    """
    
    execution_id = execution_result.get('execution_id')
    pipeline_type = execution_result.get('pipeline_type')
    environment = execution_result.get('environment')
    tenant_id = execution_result.get('tenant_id', 'N/A')
    status = execution_result.get('status', 'unknown')
    
    timestamp = int(datetime.now().timestamp())
    
    item = {
        'session_id': execution_id,
        'timestamp': timestamp,
        'environment': environment,
        'tenant_id': tenant_id,
        'pipeline_type': pipeline_type,
        'status': status,
        'details': json.dumps(execution_result),
        'ttl': timestamp + (30 * 24 * 60 * 60)  # 30 days
    }
    
    memory_table.put_item(Item=item)
    print(f"Stored execution {execution_id} in memory")
