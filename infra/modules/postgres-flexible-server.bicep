// Azure Cosmos DB for PostgreSQL (single-node cluster)
// Replaces Azure Database for PostgreSQL Flexible Server which is restricted
// in some subscriptions. The admin login is always 'citus' for Cosmos PG.

@description('The Cosmos DB for PostgreSQL cluster name')
param serverName string

@description('The PostgreSQL database name (created via post-deployment script)')
param databaseName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('Tags for all resources')
param tags object = {}

@description('The PostgreSQL administrator password (login is always "citus")')
@secure()
param administratorPassword string

resource cluster 'Microsoft.DBforPostgreSQL/serverGroupsv2@2023-03-02-preview' = {
  name: serverName
  location: location
  tags: tags
  properties: {
    administratorLoginPassword: administratorPassword
    coordinatorServerEdition: 'BurstableMemoryOptimized'
    coordinatorStorageQuotaInMb: 131072
    coordinatorVCores: 2
    enableHa: false
    coordinatorEnablePublicIpAccess: true
    nodeCount: 0
    postgresqlVersion: '16'
  }
}

// Note: Cosmos DB for PostgreSQL does not support child database resources.
// The application database must be created via a post-deployment SQL command:
//   CREATE DATABASE ${databaseName};

output serverFqdn string = '${serverName}.c.postgres.cosmos.azure.com'
output serverId string = cluster.id
output databaseName string = databaseName
