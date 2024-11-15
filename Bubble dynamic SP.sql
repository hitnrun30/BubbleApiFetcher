ALTER PROCEDURE DynamicTablePagination
    @BaseUrl NVARCHAR(MAX),
    @ApiKey NVARCHAR(MAX),
    @ObjectFields NVARCHAR(MAX) = NULL
AS
BEGIN
    DECLARE @ObjectList TABLE (ObjectName NVARCHAR(50), FieldList NVARCHAR(MAX))
    DECLARE @Object NVARCHAR(50), @Fields NVARCHAR(MAX), @CursorPosition INT = 0, @RecordCount INT, @BatchSize INT = 20

    -- Step 1: Parse Objects and Fields
    DECLARE @CurrentObject NVARCHAR(MAX), @Pos INT = 1, @CurrentChar CHAR(1), @ParenthesisDepth INT = 0
    SET @CurrentObject = ''

    -- Parse the object fields
    WHILE @Pos <= LEN(@ObjectFields)
    BEGIN
        SET @CurrentChar = SUBSTRING(@ObjectFields, @Pos, 1)
        IF @CurrentChar = '(' SET @ParenthesisDepth += 1
        IF @CurrentChar = ')' SET @ParenthesisDepth -= 1

        IF @CurrentChar = ',' AND @ParenthesisDepth = 0
        BEGIN
            IF CHARINDEX('(', @CurrentObject) > 0 AND CHARINDEX(')', @CurrentObject) > CHARINDEX('(', @CurrentObject)
            BEGIN
                SET @Object = TRIM(SUBSTRING(@CurrentObject, 1, CHARINDEX('(', @CurrentObject) - 1))
                SET @Fields = TRIM(SUBSTRING(@CurrentObject, CHARINDEX('(', @CurrentObject) + 1, CHARINDEX(')', @CurrentObject) - CHARINDEX('(', @CurrentObject) - 1))
            END
            ELSE
            BEGIN
                SET @Object = TRIM(@CurrentObject)
                SET @Fields = '*'
            END
            INSERT INTO @ObjectList (ObjectName, FieldList) VALUES (@Object, @Fields)
            SET @CurrentObject = ''
        END
        ELSE
            SET @CurrentObject += @CurrentChar

        SET @Pos += 1
    END

    -- Final insert for remaining object fields
    IF LEN(@CurrentObject) > 0
    BEGIN
        IF CHARINDEX('(', @CurrentObject) > 0 AND CHARINDEX(')', @CurrentObject) > CHARINDEX('(', @CurrentObject)
        BEGIN
            SET @Object = TRIM(SUBSTRING(@CurrentObject, 1, CHARINDEX('(', @CurrentObject) - 1))
            SET @Fields = TRIM(SUBSTRING(@CurrentObject, CHARINDEX('(', @CurrentObject) + 1, CHARINDEX(')', @CurrentObject) - CHARINDEX('(', @CurrentObject) - 1))
        END
        ELSE
        BEGIN
            SET @Object = TRIM(@CurrentObject)
            SET @Fields = '*'
        END
        INSERT INTO @ObjectList (ObjectName, FieldList) VALUES (@Object, @Fields)
    END

    -- Step 2: Process Each Object
    DECLARE obj_cursor CURSOR FOR SELECT ObjectName, FieldList FROM @ObjectList
    OPEN obj_cursor
    FETCH NEXT FROM obj_cursor INTO @Object, @Fields

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT 'Processing object ' + @Object
        DECLARE @Url NVARCHAR(MAX) = @BaseUrl + '/obj/' + @Object

        BEGIN TRY
            SET @RecordCount = dbo.GetRecordCount(@BaseUrl, @ApiKey, @Object)
            PRINT 'Record Count Retrieved: ' + CAST(@RecordCount AS NVARCHAR)
        END TRY
        BEGIN CATCH
            PRINT 'Error retrieving record count for ' + @Object + '. Skipping...'
            PRINT 'Error Details: ' + ERROR_MESSAGE()
            FETCH NEXT FROM obj_cursor INTO @Object, @Fields
            CONTINUE
        END CATCH

        -- Drop the temporary table if it exists
        DECLARE @TempTableName NVARCHAR(MAX) = '##' + @Object + 'TempData'
        IF OBJECT_ID('tempdb..' + @TempTableName) IS NOT NULL
            EXEC('DROP TABLE ' + @TempTableName)

        -- Dynamic Table Creation
        DECLARE @CreateTableSQL NVARCHAR(MAX), @InsertSQL NVARCHAR(MAX)

        IF @Fields = '*'
            SET @CreateTableSQL = 'CREATE TABLE ' + @TempTableName + ' (Data NVARCHAR(MAX));'
        ELSE
        BEGIN
            -- Wrap each trimmed field in brackets for table creation
            DECLARE @FormattedFields NVARCHAR(MAX) = ''
            DECLARE @Field NVARCHAR(100)
            DECLARE field_cursor CURSOR FOR
                SELECT TRIM(value) AS Field
                FROM STRING_SPLIT(@Fields, ',')

            OPEN field_cursor
            FETCH NEXT FROM field_cursor INTO @Field

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @FormattedFields += '[' + @Field + '] NVARCHAR(MAX), '
                FETCH NEXT FROM field_cursor INTO @Field
            END

            CLOSE field_cursor
            DEALLOCATE field_cursor

            -- Remove the last comma and add closing parenthesis
            SET @FormattedFields = LEFT(@FormattedFields, LEN(@FormattedFields) - 2) + ')'
            SET @CreateTableSQL = 'CREATE TABLE ' + @TempTableName + ' (' + @FormattedFields + ');'
        END

        -- Fetch data and insert dynamically
        SET @CursorPosition = 0
        SET @InsertSQL = 'DECLARE @CursorPos INT = 0; WHILE @CursorPos < ' + CAST(@RecordCount AS NVARCHAR) + ' BEGIN ' +
                         'DECLARE @FetchedData NVARCHAR(MAX); ' +
                         'SET @FetchedData = dbo.GetDynamicData(''' + @BaseUrl + ''', ''' + @ApiKey + ''', ''' + @Object + ''', @CursorPos, ' + CAST(@BatchSize AS NVARCHAR) + '); ' +
                         'PRINT ''Fetched data for batch starting at '' + CAST(@CursorPos AS NVARCHAR);'

        IF @Fields = '*'
            SET @InsertSQL += 'INSERT INTO ' + @TempTableName + ' (Data) SELECT value FROM OPENJSON(@FetchedData, ''$.response.results'');'
        ELSE
        BEGIN
            -- Build the bracketed fields for the insert
            DECLARE @BracketedFields NVARCHAR(MAX) = REPLACE(@FormattedFields, ' NVARCHAR(MAX)', '')
            -- Build field list for OPENJSON with brackets and trimmed names
            SET @InsertSQL += 'INSERT INTO ' + @TempTableName + ' (' + @BracketedFields + ') ' +
                              'SELECT ' + @BracketedFields + ' FROM OPENJSON(@FetchedData, ''$.response.results'') WITH (' + @FormattedFields + ');'
        END

        SET @InsertSQL += 'SET @CursorPos += ' + CAST(@BatchSize AS NVARCHAR) + '; END;'

        DECLARE @FinalSQL NVARCHAR(MAX) = @CreateTableSQL + ' ' + @InsertSQL
        PRINT @FinalSQL  -- For debugging
        EXEC sp_executesql @FinalSQL

        PRINT 'Data inserted into temporary table ' + @TempTableName

        FETCH NEXT FROM obj_cursor INTO @Object, @Fields
    END

    CLOSE obj_cursor
    DEALLOCATE obj_cursor

    PRINT 'All data fetched and stored in individual temporary tables successfully.'
END
