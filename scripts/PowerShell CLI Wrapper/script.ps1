# PowerShell Application Wrapper for Magnet AUTOMATE

$application_name = "My Application CLI"
$application_path = "X:\Tools\Application\application.exe"
$success_exit_code = 0

$params = @(
    "--output `"${OUTPUT_PATH}`"",
    "--other other_value"
    "`"${IMAGE_PATH}`""
)

Write-Host "[$application_name] Starting process."
$process = Start-Process -FilePath $application_path -ArgumentList $params -NoNewWindow -Wait -PassThru
$exit_code = $process.ExitCode

if($exit_code -eq $success_exit_code){
    # Exit workflow element as success
    Write-Host "[$application_name] Process finished with exit code $exit_code."
    Exit(0)
} else {
    # Exit workflow element as failure
    Write-Host "[$application_name] Process finished with exit code $exit_code."
    Exit(1)
}
