.\mcp.ps1 -Persona operator -Tool kafka_list_topics
.\mcp.ps1 -Persona operator -Tool flink_get_cluster_info
.\mcp.ps1 -Persona operator -Tool iceberg_list_namespaces
.\mcp.ps1 -Persona operator -Tool spark_list_applications -Arguments @{ limit = 10 }
.\mcp.ps1 -Persona operator -Tool connect_list_connectors
