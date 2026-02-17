# Compute Pipeline Guide

## Purpose
Provision EC2 instances for tenant workloads.

## Prerequisites
- Bootstrap infrastructure must exist
- VPC and subnets available
- Security groups configured

## Parameters
- Tenant ID (required)
- Instance type (default: t3.medium)
- Instance count (default: 1)
- Environment (dev or prod)

## Instance Configuration
- Deployed in private subnets
- Auto-assigned security groups
- Tagged with tenant ID
- Monitoring enabled

## Multi-Tenant Support
Each tenant gets isolated compute resources:
- Separate security groups
- Dedicated instances
- Tagged for cost allocation
