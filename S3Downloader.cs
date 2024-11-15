using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using CsvHelper;
using System.Globalization;
using System.Collections.Generic;

namespace BubbleApiFetcher
{
    public class S3PublicFileDownloader
    {
        // Make the method public so it can be called from PowerShell
        public async Task DownloadFilesFromCsv(string csvFilePath)
        {
            using var reader = new StreamReader(csvFilePath);
            using var csv = new CsvReader(reader, CultureInfo.InvariantCulture);

            var records = csv.GetRecords<S3FileRecord>();

            foreach (var record in records)
            {
                try
                {
                    Console.WriteLine($"Downloading {record.S3FilePath} to {record.LocalDestination}");
                    await DownloadFileFromUrl(record.S3FilePath, record.LocalDestination);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error downloading {record.S3FilePath}: {ex.Message}");
                }
            }
        }

        // Make the method public so it can be called from PowerShell
        public async Task DownloadFileFromUrl(string fileUrl, string localDestination)
        {
            using var client = new HttpClient();
            var response = await client.GetAsync(fileUrl);
            response.EnsureSuccessStatusCode();

            using (var fs = new FileStream(localDestination, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                await response.Content.CopyToAsync(fs);
            }
        }
    }

    public class S3FileRecord
    {
        public string S3FilePath { get; set; }
        public string LocalDestination { get; set; }
    }
}
