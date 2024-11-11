
# Bubble API Integration with SQL Server and C#

## Overview

This repository provides a way to integrate Bubble API data with SQL Server, allowing dynamic querying of Bubble objects. The solution consists of a C# DLL for handling API requests and SQL Server procedures for storing and processing the fetched data.

## Prerequisites

1. **SQL Server**: This solution uses SQL Server with CLR integration enabled.
2. **C# Development Environment**: For building the `BubbleApiFetcher` DLL.
3. **Bubble API**: You need API access to your Bubble application.

## Step 1: C# DLL - BubbleApiFetcher

### 1.1 Build the C# DLL

This repository includes `BubbleApiFetcher.cs`, which contains two main functions:
- `GetRecordCount`: Retrieves the total count of records for a specified object.
- `GetDynamicData`: Fetches a batch of data for a specified object and cursor.

**Instructions**:
1. Open the project in Visual Studio.
2. Build the project to generate `BubbleApiFetcher.dll`.

### 1.2 Register the DLL in SQL Server

- Copy the `BubbleApiFetcher.dll` to a secure location accessible by SQL Server.

## Step 2: SQL Server Configuration

### 2.1 Enable CLR Integration

Execute the following commands to enable CLR integration in SQL Server:

```sql
sp_configure 'clr enabled', 1;
RECONFIGURE;
```

### 2.2 Create the Assembly

Load the `BubbleApiFetcher.dll` into SQL Server:

```sql
CREATE ASSEMBLY BubbleApiFetcher
FROM 'C:\path\to\BubbleApiFetcher.dll'
WITH PERMISSION_SET = EXTERNAL_ACCESS;
```

### 2.3 Add the Trusted Assembly

After creating the assembly, mark it as trusted to allow external access:

1. Calculate the SHA-512 hash of `BubbleApiFetcher.dll`:

    ```powershell
    Get-FileHash -Algorithm SHA512 -Path "C:\path\to\BubbleApiFetcher.dll"
    ```

2. Add the trusted assembly using the computed hash:

    ```sql
    EXEC sp_add_trusted_assembly 
        @hash = '<assembly_hash>', 
        @description = 'BubbleApiFetcher for Bubble API Integration';
    ```

   Replace `<assembly_hash>` with the actual hash.

### 2.4 Create SQL Server Functions

Define the CLR functions that interact with the assembly:

```sql
CREATE FUNCTION GetRecordCount (
    @baseUrl NVARCHAR(4000),
    @apiKey NVARCHAR(4000),
    @objectName NVARCHAR(4000)
)
RETURNS INT
AS EXTERNAL NAME BubbleApiFetcher.BubbleApiFetcher.GetRecordCount;

CREATE FUNCTION GetDynamicData (
    @baseUrl NVARCHAR(4000),
    @apiKey NVARCHAR(4000),
    @objectName NVARCHAR(4000),
    @cursor INT,
    @limit INT
)
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME BubbleApiFetcher.BubbleApiFetcher.GetDynamicData;
```

## Step 3: SQL Stored Procedures

### 3.1 DynamicTablePagination Procedure

This stored procedure dynamically fetches and stores data for specified objects and fields from Bubble. Example usage:

```sql
EXEC DynamicTablePagination
    @BaseUrl = 'https://your-bubble-app.bubbleapps.io/api/1.1',
    @ApiKey = 'your_api_key',
    @ObjectFields = 'policy(Policy Number, Expiration, Status),driver(*)';
```

### 3.2 Explanation of the Procedure

- **Parameters**: `@BaseUrl`, `@ApiKey`, `@ObjectFields`.
- **Table Creation**: Dynamically creates temp tables based on fields specified.
- **Data Fetching**: Uses `GetDynamicData` to retrieve data in batches and inserts it into temp tables.

## Usage

To retrieve data after running `DynamicTablePagination`, query the temp tables created (e.g., `##policyTempData`).
Format is `apikeyname1(field1, field2, Field3),apikeyname2(*)`
    If you submit a * it will give you the raw JSON.

## Troubleshooting

- **Permission Errors**: Ensure `BubbleApiFetcher.dll` is trusted with the correct SHA-512 hash.
- **CLR Integration**: Verify CLR is enabled in SQL Server.
