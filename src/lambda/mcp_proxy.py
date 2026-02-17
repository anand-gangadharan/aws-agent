"""
Lambda function that proxies MCP tool calls from Bedrock agents.
This invokes the MCP server Lambda function directly.
"""

import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')

memory_table = dynamodb.Table(os.environ['MEMORY_TABLE_NAME'])
mcp_server_function = os.environ.get('MCP_SERVER_FUNCTION_NAME')

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
        # Invoke MCP server Lambda directly
        result = invoke_mcp_server_lambda(api_path, params)
        
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

def invoke_mcp_server_lambda(api_path, params):
    """
    Invoke MCP server Lambda function directly.
    This is more reliable than HTTP calls.
    """
    
    print(f"Invoking MCP server Lambda: {mcp_server_function}")
    print(f"API Path: {api_path}")
    print(f"Parameters: {json.dumps(params)}")
    
    # Map API path to pipeline type
    pipeline_type_map = {
        '/mcp/execute-bootstrap': 'bootstrap',
        '/mcp/execute-compute': 'compute',
        '/mcp/execute-app': 'app'
    }
    
    if api_path in pipeline_type_map:
        # Execute pipeline
        payload = {
            'action': 'execute',
            'pipeline_type': pipeline_type_map[api_path],
            'environment': params.get('environment'),
            'tenant_id': params.get('tenant_id'),
            'region': params.get('region'),
            'instance_type': params.get('instance_type'),
            'instance_count': params.get('instance_count'),
            'app_name': params.get('app_name'),
            'app_version': params.get('app_version'),
            'parameters': params
        }
    elif api_path == '/mcp/get-status':
        # Get status
        payload = {
            'action': 'status',
            'execution_id': params.get('execution_id')
        }
    else:
        return {'error': f'Unknown API path: {api_path}'}
    
    # Invoke MCP server Lambda
    response = lambda_client.invoke(
        FunctionName=mcp_server_function,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )
    
    # Parse response
    response_payload = json.loads(response['Payload'].read())
    
    print(f"MCP server response: {json.dumps(response_payload)}")
    
    return response_payload

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
