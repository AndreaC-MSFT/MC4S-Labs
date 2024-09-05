# DISCLAIMER:
# This script is provided as-is and for demonstration purposes only.
# Use at your own risk.
# This script is meant as a short-term fix for non-US customers using teh data trail feature


param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Please enter the absolute or relative path to the csv file to be converted")]
    [string]$csvPath
)

# Get the path to the CSV file
if (-not (Test-Path -Path $csvPath)) {
    Write-Error "The file path '$csvPath' does not exist. Please provide a valid path."
    exit
}
if ([System.IO.Path]::GetExtension($csvPath).ToLower() -ne ".csv") {
    Write-Error "The file '$csvPath' is not a CSV file. Please provide a valid CSV file."
    exit
}


# Define output file
$directory = [System.IO.Path]::GetDirectoryName($csvPath)
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($csvPath)
$extension = [System.IO.Path]::GetExtension($csvPath)
$outFileName = "$fileName-UKFormat$extension"
$outCsvPath = [System.IO.Path]::Combine($directory, $outFileName)

# Import the CSV file
$data = Import-Csv -Path $csvPath

# Define the criteria to determine the date columns
$dateColumns = @("date", "created on", "modified on")

# Function to convert date format
function Convert-DateFormat {
    param (
        [string]$dateString
    )
    try {
        if ($dateString -match "\d{1,2}/\d{1,2}/\d{4}") {
            $date = [datetime]::ParseExact($dateString, "M/d/yyyy h:mm:ss tt", $null)
            return $date.ToString("dd/MM/yyyy HH:mm:ss")
        }
        return $dateString
    } catch {
        Write-Warning "Failed to parse date: $dateString"
        return $dateString
    }
}

# Initialize progress reporting
$totalRows = $data.Count
$currentRow = 0
$progressInterval = 100  # Update progress every 10 rows

# Iterate through each row and convert the date formats
foreach ($row in $data) {
    # Update progress bar at defined intervals
    if ($currentRow % $progressInterval -eq 0 -or $currentRow -eq $totalRows - 1) {
        $percentComplete = [math]::Round(($currentRow / $totalRows) * 100)
        Write-Progress -Activity "Converting Dates" -Status "Processing row $currentRow of $totalRows" -PercentComplete $percentComplete
    }

    foreach ($column in $row.PSObject.Properties.Name) {
        foreach ($dateColumn in $dateColumns) {
            if ($column -match "(?i)$dateColumn") {
                $row.$column = Convert-DateFormat -dateString $row.$column
            }
        }
    }
    $currentRow++
}

# Export the modified data back to a CSV file with error handling
try {
    $data | Export-Csv -Path $outCsvPath -NoTypeInformation
    Write-Output "Date conversion completed and saved to $outCsvPath"
} catch {
    Write-Error "Failed to export CSV file. Please check the output path and permissions."
}
