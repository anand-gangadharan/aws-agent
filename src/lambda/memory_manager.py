import json
import os
import boto3
from datetime import datetime
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
memory_table = dynamodb.Table(os.environ['MEMORY_TABLE_NAME'])

def handler(event, context):
    """Lambda handler for memory operations"""
    
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
        if api_path == '/memory/query':
            result = query_memory(params)
        elif api_path == '/memory/store':
            result = store_memory(params)
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

def query_memory(params):
    """Query deployment history"""
    environment = params.get('environment')
    tenant_id = params.get('tenant_id')
    
    items = []
    
    if environment:
        response = memory_table.query(
            IndexName='environment-index',
            KeyConditionExpression=Key('environment').eq(environment),
            ScanIndexForward=False,
            Limit=50
        )
        items.extend(response.get('Items', []))
    
    if tenant_id:
        response = memory_table.query(
            IndexName='tenant-index',
            KeyConditionExpression=Key('tenant_id').eq(tenant_id),
            ScanIndexForward=False,
            Limit=50
        )
        items.extend(response.get('Items', []))
    
    # Remove duplicates and sort by timestamp
    unique_items = {item['session_id']: item for item in items}
    sorted_items = sorted(
        unique_items.values(),
        key=lambda x: x.get('timestamp', 0),
        reverse=True
    )
    
    return {
        'count': len(sorted_items),
        'deployments': sorted_items[:20]  # Return last 20
    }

def store_memory(params):
    """Store deployment record"""
    import uuid
    
    session_id = str(uuid.uuid4())
    timestamp = int(datetime.now().timestamp())
    
    item = {
        'session_id': session_id,
        'timestamp': timestamp,
        'environment': params.get('environment', 'unknown'),
        'tenant_id': params.get('tenant_id', 'N/A'),
        'pipeline_type': params.get('pipeline_type'),
        'status': params.get('status'),
        'details': json.dumps(params.get('details', {})),
        'ttl': timestamp + (30 * 24 * 60 * 60)  # 30 days
    }
    
    memory_table.put_item(Item=item)
    
    return {
        'status': 'stored',
        'session_id': session_id
    }
