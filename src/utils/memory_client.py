"""DynamoDB memory client utilities"""

import boto3
from datetime import datetime
from typing import List, Dict, Any, Optional
from boto3.dynamodb.conditions import Key

class MemoryClient:
    def __init__(self, table_name: str, region: str = 'us-east-1'):
        dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = dynamodb.Table(table_name)
    
    def store_deployment(
        self,
        session_id: str,
        environment: str,
        pipeline_type: str,
        status: str,
        tenant_id: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Store a deployment record"""
        
        timestamp = int(datetime.now().timestamp())
        
        item = {
            'session_id': session_id,
            'timestamp': timestamp,
            'environment': environment,
            'tenant_id': tenant_id or 'N/A',
            'pipeline_type': pipeline_type,
            'status': status,
            'details': str(details or {}),
            'ttl': timestamp + (30 * 24 * 60 * 60)  # 30 days
        }
        
        self.table.put_item(Item=item)
        return item
    
    def query_by_environment(
        self,
        environment: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Query deployments by environment"""
        
        response = self.table.query(
            IndexName='environment-index',
            KeyConditionExpression=Key('environment').eq(environment),
            ScanIndexForward=False,
            Limit=limit
        )
        
        return response.get('Items', [])
    
    def query_by_tenant(
        self,
        tenant_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Query deployments by tenant"""
        
        response = self.table.query(
            IndexName='tenant-index',
            KeyConditionExpression=Key('tenant_id').eq(tenant_id),
            ScanIndexForward=False,
            Limit=limit
        )
        
        return response.get('Items', [])
    
    def get_latest_deployment(
        self,
        environment: str,
        pipeline_type: str
    ) -> Optional[Dict[str, Any]]:
        """Get the latest deployment for environment and pipeline type"""
        
        items = self.query_by_environment(environment)
        
        for item in items:
            if item.get('pipeline_type') == pipeline_type:
                return item
        
        return None
