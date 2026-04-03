<#
.SYNOPSIS

v 1.0.2
-- Vladimir Kostic
-- 24/Feb/2025
-- In this version of the script, it has been added that wildcard characters can be used in the names of files or folders that should be exempted from deletion.
-- Additionally, the script now ensures that subfolders within excluded folders are also not deleted, preserving the entire directory structure of excluded folders.

Delete all files and subfolders from a specific folder on a Windows Remote Server with an exclude list for subfolders or files.

DESCRIPTION

The script is called by default from the Jenkins pipeline project script to delete all files from a project folder on a Remote Windows IIS Server before deploying new files.
However, it can be used to delete any file on any Windows Remote Server where WinRM is enabled from the FE-JENKINS Server.

.PARAMETER $parmEnvVariableName

String parameter. The name of the Environment variable used for connection to the Windows Remote Server. 
No default value, empty string.
Variables $parmUserName, $parmPass, $parmServerName used in the script get their values from this Environment variable.   
Required. It is necessary to pass this parameter.

.PARAMETER $parmFolderPath

String parameter. The full absolute path to the folder from which we want to delete files on the Windows Remote Server.
No default value, empty string. 
Required. It is necessary to pass this parameter.

.PARAMETER $parmExcludeFileNames

List of file names you want to exclude from deletion from the folder.
No default value, empty string.
Not Required. Only if you want to exclude some files from being deleted from the folder.
Wildcard characters are allowed in the file name.
Examples: 
@('web.config','appsettings.json')
@('web.*','*.json')

.PARAMETER $parmExcludeFolderNames

List of subfolder names you want to exclude from deletion from the folder.
No default value, empty string.
Not Required. Only if you want to exclude some subfolders from being deleted from the folder.
Wildcard characters are allowed in the folder name.
Examples: 
@('Data','bin')
@('*Data','bin*')

.EXAMPLE

This is an example of a Script call with parameters from a Jenkins Pipeline Project:

pwsh("C:\\scripts\\DeleteFileOnRemoteServer.ps1 -parmEnvVariableName QA_WRM_USER -parmFolderPath 'c:\\inetpub\\wwwroot\\WebSite QA\\' -parmExcludeFileNames @('appsettings.json', 'web.config') -parmExcludeFolderNames @('DO-NOT-DELETE')")

.NOTES

In this version, the script has been enhanced to ensure that:
1. Wildcard characters can be used in the names of files or folders that should be exempted from deletion.
2. Subfolders within excluded folders are also preserved, ensuring that the entire directory structure of excluded folders remains intact.
#>
param (
    [String]$parmEnvVariableName = "",
    [String]$parmFolderPath = "",
    [String[]]$parmExcludeFileNames = @(),  
    [String[]]$parmExcludeFolderNames = @() 
)

$jsonFilePath = (Get-Item -Path "Env:$($parmEnvVariableName)").Value
$jsonContent = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json

$parmUserName = $jsonContent.UserName
$parmPass = $jsonContent.Password
$parmServerName = $jsonContent.ServerName

$securePassword = ConvertTo-SecureString $parmPass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($parmUserName, $securePassword)

# Invoke the script on the remote server
Invoke-Command -ComputerName $parmServerName -Credential $credential -ScriptBlock {
    $folderPath = $using:parmFolderPath
    $excludeFileNames = $using:parmExcludeFileNames    
    $excludeFolderNames = $using:parmExcludeFolderNames

    # Function to check if an item should be excluded
    function Should-Exclude {
        param (
            [string]$itemName,
            [string[]]$excludePatterns
        )
        foreach ($pattern in $excludePatterns) {
            if ($itemName -like $pattern) {
                return $true
            }
        }
        return $false
    }

    # Function to check if an item is within an excluded folder
    function Is-WithinExcludedFolder {
        param (
            [string]$itemPath,
            [string[]]$excludeFolderPatterns
        )
        foreach ($excludedFolder in $excludeFolderPatterns) {
            if ($itemPath -like "*\$excludedFolder\*") {
                return $true
            }
        }
        return $false
    }

    # Get all items in the folder (recursive)
    $itemsToDelete = Get-ChildItem -Path $folderPath -Recurse

    # Process files first
    foreach ($item in $itemsToDelete) {
        Write-Output "Processing files: $($item.FullName)"
        if ($item.PSIsContainer -eq $false) {  # Only process files
            # Check if the file is excluded
            if ($excludeFileNames.Count -gt 0) {
                $isFileExcluded = Should-Exclude $item.Name $excludeFileNames
                Write-Output "Checking if file is excluded: $($item.Name) - $isFileExcluded"
            } else {
                $isFileExcluded = $false
                Write-Output "No file exclusions specified."
            }
            
            # Check if the file is within an excluded folder
            if ($excludeFolderNames.Count -gt 0) {
                $isWithinExcludedFolder = Is-WithinExcludedFolder -itemPath $item.FullName -excludeFolderPatterns $excludeFolderNames
                Write-Output "Checking if file is within excluded folder: $($item.FullName) - $isWithinExcludedFolder"
            } else {
                $isWithinExcludedFolder = $false
                Write-Output "No folder exclusions specified."
            }

            if ($isFileExcluded -or $isWithinExcludedFolder) {
                Write-Output "Excluded file: $($item.FullName) (File or parent folder is excluded)"
            } else {
                try {
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                    Write-Output "Deleted file: $($item.FullName)"
                }
                catch {
                    Write-Output "Failed to delete file: $($item.FullName) - $($_.Exception.Message)"
                }
            }
        }
    }

    # Process folders (bottom-up, starting from the deepest level)
    $foldersToDelete = $itemsToDelete | Where-Object { $_.PSIsContainer -eq $true } | Sort-Object { $_.FullName.Length } -Descending

    foreach ($folder in $foldersToDelete) {
        # Check if the folder is excluded
        if ($excludeFolderNames.Count -gt 0) {
            $isFolderExcluded = Should-Exclude $folder.Name $excludeFolderNames
            Write-Output "Checking if folder is excluded: $($folder.Name) - $isFolderExcluded"
        } else {
            $isFolderExcluded = $false
            Write-Output "No folder exclusions specified."
        }

        # Check if the folder is within an excluded folder
        if ($excludeFolderNames.Count -gt 0) {
            $isWithinExcludedFolder = Is-WithinExcludedFolder -itemPath $folder.FullName -excludeFolderPatterns $excludeFolderNames
            Write-Output "Checking if folder is within excluded folder: $($folder.FullName) - $isWithinExcludedFolder"
        } else {
            $isWithinExcludedFolder = $false
            Write-Output "No folder exclusions specified."
        }

        if ($isFolderExcluded -or $isWithinExcludedFolder) {
            Write-Output "Excluded folder: $($folder.FullName) (Folder or parent folder is excluded)"
        } else {
            try {
                # Check if the folder is empty before deleting
                if ((Get-ChildItem -Path $folder.FullName -Recurse -ErrorAction SilentlyContinue).Count -eq 0) {
                    Remove-Item -Path $folder.FullName -Force -Recurse -ErrorAction Stop
                    Write-Output "Deleted folder: $($folder.FullName)"
                } else {
                    Write-Output "Folder not empty, skipping: $($folder.FullName)"
                }
            }
            catch {
                Write-Output "Failed to delete folder: $($folder.FullName) - $($_.Exception.Message)"
            }
        }
    }
}