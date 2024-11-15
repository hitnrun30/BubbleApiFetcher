using System;
using System.Data.SqlTypes;
using System.Net;
using Microsoft.SqlServer.Server;

public class BubbleApiFetcher
{
    [SqlFunction(DataAccess = DataAccessKind.Read, IsDeterministic = true)]
    public static SqlInt32 GetRecordCount(SqlString baseUrl, SqlString apiKey, SqlString objectName)
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

        using (WebClient client = new WebClient())
        {
            client.Headers.Add("Authorization", $"Bearer {apiKey.Value}");
            string apiUrl = $"{baseUrl.Value}/obj/{objectName}?limit=1";

            try
            {
                string jsonResponse = client.DownloadString(apiUrl);
                
                // Extract "remaining" value using basic string manipulation
                int remainingIndex = jsonResponse.IndexOf("\"remaining\":") + "\"remaining\":".Length;
                if (remainingIndex > "\"remaining\":".Length - 1)
                {
                    int endOfValue = jsonResponse.IndexOfAny(new char[] { ',', '}' }, remainingIndex);
                    string remainingValue = jsonResponse.Substring(remainingIndex, endOfValue - remainingIndex).Trim();
                    
                    // Parse remaining and add 1 for total count
                    if (int.TryParse(remainingValue, out int remaining))
                    {
                        return new SqlInt32(remaining + 1);
                    }
                }
                return new SqlInt32(0); // Fallback in case of parsing issues
            }
            catch (Exception ex)
            {
                throw new Exception("Error retrieving record count", ex);
            }
        }
    }

    [SqlFunction(DataAccess = DataAccessKind.Read, IsDeterministic = true)]
    public static SqlString GetDynamicData(SqlString baseUrl, SqlString apiKey, SqlString objectName, int cursor, int limit)
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

        using (WebClient client = new WebClient())
        {
            client.Headers.Add("Authorization", $"Bearer {apiKey.Value}");
            string apiUrl = $"{baseUrl.Value}/obj/{objectName}?cursor={cursor}&limit={limit}";

            try
            {
                string jsonResponse = client.DownloadString(apiUrl);
                return new SqlString(jsonResponse);
            }
            catch (Exception ex)
            {
                throw new Exception("Error fetching data", ex);
            }
        }
    }
}
