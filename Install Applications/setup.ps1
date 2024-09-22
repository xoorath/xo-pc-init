# Directory for logs
$outputDir = "$PSScriptRoot\output"
$summaryFile = "$outputDir\summary.txt"
$errorsFile = "$outputDir\errors.txt"

# Initialize summary and errors logs
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Clear-Content -Path $summaryFile -ErrorAction SilentlyContinue
Clear-Content -Path $errorsFile -ErrorAction SilentlyContinue
Write-Host "Log directory: $outputDir"

# Log helper function
function Log-Output {
    param ($appName, $message, $isError = $false)

    $logFile = Join-Path -Path $outputDir -ChildPath "$appName.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $formattedMessage = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $formattedMessage

    if ($isError) {
        Add-Content -Path $errorsFile -Value "$appName: $message"
    }

    # Print success/failure into the summary file at the end
    Add-Content -Path $summaryFile -Value "$appName: $message"
}

# Function to install applications from winget, pip, or URL with error handling
function Install-App {
    param ($app, $forceInstall)

    $appName = $app.name

    try {
        if (-not $forceInstall -and Is-AppInstalled $appName) {
            Write-Host "$appName is already installed. Skipping."
            Log-Output -appName $appName -message "$appName is already installed. Skipping."
            return
        }

        if ($app.source -eq "winget") {
            Write-Host "Installing $appName via Winget..."
            Log-Output -appName $appName -message "Installing $appName via Winget..."
            winget install $appName --silent | Tee-Object -FilePath (Join-Path $outputDir "$appName.txt")
        } elseif ($app.source -eq "pip") {
            Write-Host "Installing $appName via pip..."
            Log-Output -appName $appName -message "Installing $appName via pip..."
            pip install $appName | Tee-Object -FilePath (Join-Path $outputDir "$appName.txt")
        } elseif ($app.source -eq "url") {
            Write-Host "Installing $appName from URL..."
            Log-Output -appName $appName -message "Installing $appName from URL..."
            $installerPath = "$env:TEMP\$($app.name).exe"
            Invoke-WebRequest -Uri $app.url -OutFile $installerPath
            Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
            Log-Output -appName $appName -message "$appName installed from URL."
        } elseif ($app.source -eq "wsl") {
            Write-Host "Installing WSL and $($app.distro)..."
            wsl --install -d $app.distro | Tee-Object -FilePath (Join-Path $outputDir "$appName.txt")
            Log-Output -appName $appName -message "Installed WSL with $($app.distro)"
        }

        # Log success
        Log-Output -appName $appName -message "$appName installation completed successfully."
    } catch {
        # Catch any errors and log them
        $errorMessage = "$appName installation failed: $_"
        Write-Host $errorMessage -ForegroundColor Red
        Log-Output -appName $appName -message $errorMessage -isError $true
    }
}

# Function to summarize all installations at the end
function Final-Summary {
    Write-Host "Summary of Installations:"
    Get-Content -Path $summaryFile
    Write-Host "Errors (if any):"
    Get-Content -Path $errorsFile
}

# Example of running an installation group
function Install-Group {
    param ($group)

    foreach ($app in $group.applications) {
        Install-App -app $app -forceInstall $false
    }

    # Reboot between groups if needed
    if ($group.requiresRestart) {
        Write-Host "Restarting the system for group: $($group.name)..."
        shutdown /r /t 5
        exit
    }
}

# Install each group
foreach ($group in $config.groups) {
    Install-Group -group $group
}

# Print the summary at the end
Final-Summary
