param (
    [string]$CsvFilePath,
    [string]$S3FileLocation,
    [string]$LocalDestination,
    [switch]$UseCsvFile
)

# Validate the input parameters
if ($UseCsvFile) {
    if (-not $CsvFilePath) {
        Write-Host "Error: You must specify a CSV file path when using the -UseCsvFile flag."
        exit 1
    }
    if ($S3FileLocation -or $LocalDestination) {
        Write-Host "Error: Cannot specify both S3 file location and local destination when using the CSV file."
        exit 1
    }
} elseif ($S3FileLocation -and $LocalDestination) {
    Write-Host "Downloading file from S3 location '$S3FileLocation' to local destination '$LocalDestination'."
} else {
    Write-Host "Error: You must either specify a CSV file or both S3 file location and local destination."
    exit 1
}

# Define the path to your compiled DLL file
$dllPath = "C:\Users\sstrauss\source\BubbleApiFetcher\BubbleApiFetcher\bin\Release\net48\BubbleApiFetcher.dll"

# Load the assembly (DLL) into PowerShell
Add-Type -Path $dllPath

# Function to download a single file
function Download-File {
    param (
        [string]$s3FileLocation,
        [string]$localDestination
    )

    try {
        # Validate URL scheme
        if ($s3FileLocation -match "^(http|https)://") {
            Write-Host "Attempting to download file from '$s3FileLocation' to '$localDestination'."
            
            # Reference the correct namespace and class (AwsFileDownloaderNamespace)
            $downloader = New-Object AwsFileDownloaderNamespace.S3PublicFileDownloader
            
            # Properly await the asynchronous method
            Write-Host "Starting download task..."
            $downloadTask = $downloader.DownloadFileFromUrl($s3FileLocation, $localDestination)
            $downloadTask.GetAwaiter().GetResult()  # Use GetAwaiter().GetResult() to synchronously wait
            Write-Host "File downloaded successfully."
        } else {
            Write-Host "Error: The URL '$s3FileLocation' is invalid. It must start with 'http://' or 'https://'."
        }
    } catch {
        Write-Host "An error occurred while downloading the file: $($_.Exception.Message)"
        Write-Host "Stack Trace: $($_.Exception.StackTrace)"
        Write-Host "S3 File URL: $s3FileLocation"
    }
}



# If using a CSV file, read the CSV and download each file
if ($UseCsvFile) {
    try {
        Write-Host "Reading CSV file '$CsvFilePath' for S3 file locations and local destinations."
        $csvData = Import-Csv -Path $CsvFilePath
        foreach ($row in $csvData) {
            if ($row.S3FilePath -and $row.LocalDestination) {
                Download-File -s3FileLocation $row.S3FilePath -localDestination $row.LocalDestination
            } else {
                Write-Host "Skipping row due to missing S3 file location or local destination."
            }
        }
    } catch {
        Write-Host "Error reading CSV file: $_"
    }
} elseif ($S3FileLocation -and $LocalDestination) {
    Download-File -s3FileLocation $S3FileLocation -localDestination $LocalDestination
} else {
    Write-Host "Error: Invalid combination of parameters."
    exit 1
}
