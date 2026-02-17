import json
import os
import boto3
import requests
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
memory_table = dynamodb.Table(os.environ['MEMORY_TABLE_NAME'])
mcp_server_url = os.environ.get('MCP_SERVER_URL', 'http://localhost:8000')

def handler(event, context):
    """Lambda handler for pipeline execution via MCP server"""
    
    print(f"Event: {json.dumps(event)}")
    
    # Parse the action group request
    action = event.get('actionGroup', '')
    api_path = event.get('apiPath', '')
    parameters = event.get('parameters', [])
    request_body = event.get('requestBody', {})
    
    # Convert parameters list to dict
    params = {p['name']: p['value'] for p in parameters}
    
    # Parse request body if present
    if request_body and 'content' in request_body:
        body_content = request_body['content']
        if isinstance(body_content, dict) and 'application/json' in body_content:
            body_data = json.loads(body_content['application/json'])
            params.update(body_data)
    
    try:
        if api_path == '/pipeline/execute':
            result = execute_pipeline(params)
        elif api_path == '/pipeline/status':
            result = get_pipeline_status(params)
        elif api_path == '/delegate':
            result = delegate_to_agent(params)
        else:
            result = {'error': f'Unknown API path: {api_path}'}
        
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

def execute_pipeline(params):
    """Execute pipeline via MCP server"""
    pipeline_type = params.get('pipeline_type')
    environment = params.get('environment')
    tenant_id = params.get('tenant_id')
    parameters = params.get('parameters', {})
    
    # Call MCP server to execute pipeline
    response = requests.post(
        f"{mcp_server_url}/execute",
        json={
            'pipeline_type': pipeline_type,
            'environment': environment,
            'tenant_id': tenant_id,
            'parameters': parameters
        },
        timeout=60
    )
    
    result = response.json()
    
    # Store execution in memory
    execution_id = result.get('execution_id')
    memory_table.put_item(
        Item={
            'session_id': execution_id,
            'timestamp': int(datetime.now().timestamp()),
            'environment': environment,
            'tenant_id': tenant_id or 'N/A',
            'pipeline_type': pipeline_type,
            'status': result.get('status'),
            'details': json.dumps(result),
            'ttl': int(datetime.now().timestamp()) + (30 * 24 * 60 * 60)  # 30 days
        }
    )
    
    return result

def get_pipeline_status(params):
    """Get pipeline execution status"""
    execution_id = params.get('execution_id')
    
    response = requests.get(
        f"{mcp_server_url}/status/{execution_id}",
        timeout=10
    )
    
    return response.json()

def delegate_to_agent(params):
    """Delegate task to specialized agent"""
    agent_type = params.get('agent_type')
    task = params.get('task')
    environment = params.get('environment')
    tenant_id = params.get('tenant_id')
    
    # This would invoke the appropriate Bedrock agent
    # For now, return a placeholder
    return {
        'status': 'delegated',
        'agent_type': agent_type,
        'task': task,
        'environment': environment,
        'tenant_id': tenant_id
    }
