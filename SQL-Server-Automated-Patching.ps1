############################################################################################################
#AUTHOR: YOUSSEF LTEIF
#DATE: 15/05/2024
############################################################################################################


# Define credentials and list of servers
$cred = Get-Credential DOMAIN\ADMIN_ACCOUNT  # Replace DOMAIN\ADMIN_ACCOUNT with actual domain and account
$listofservers = @('SQLSERVER1', 'SQLServer2.domain.com', '174.57.14.10')

# Debug flag (set to 1 for debugging output)

$debug = 0

############################################################################################################
##### Function to get the SQL Server major version year
############################################################################################################

function Get-SqlMajorVersionYear {
    param([string]$ServerInstance)
    $versionInfo = Get-DbaBuild -SqlInstance $ServerInstance -SqlCredential $cred
    if ($debug -eq 1) {
        Write-Host $versionInfo -ForegroundColor Yellow
    }
    foreach ($point in $versionInfo) {
        $majorVersionYear = $point.NameLevel
        Write-Output $majorVersionYear
    }
}

############################################################################################################
##### Function to get the current SQL Server service pack
############################################################################################################

function Get-SqlCurrentSP {
    param([string]$ServerInstance)
    $versionInfo = Get-DbaBuild -SqlInstance $ServerInstance -SqlCredential $cred
    if ($debug -eq 1) {
        Write-Host $versionInfo -ForegroundColor Yellow
    }
    foreach ($point in $versionInfo) {
        $sp = $point.SPLevel
        Write-Output $sp
    }
}

############################################################################################################
##### Function to get the current SQL Server cumulative update
############################################################################################################

function Get-SqlCurrentCU {
    param([string]$ServerInstance)
    $versionInfo = Get-DbaBuild -SqlInstance $ServerInstance -SqlCredential $cred
    if ($debug -eq 1) {
        Write-Host $versionInfo -ForegroundColor Yellow
    }
    foreach ($point in $versionInfo) {
        $cu = $point.CULevel
        Write-Output $cu
    }
}

############################################################################################################
##### Loop through each server in the list
############################################################################################################

foreach ($server in $listofservers) {
    # Get major version year, current SP, and current CU
    $mjrvrsn = Get-SqlMajorVersionYear -ServerInstance $server
    $sp = Get-SqlCurrentSP -ServerInstance $server
    $cu = Get-SqlCurrentCU -ServerInstance $server

############################################################################################################
##### Get latest SQL build reference based on the retrieved information
############################################################################################################

    $buildReference = Get-DbaBuildReference -MajorVersion $mjrvrsn -ServicePack $sp -CumulativeUpdate 99 -Update ## 99 to get largest available CU in repository
    if ($debug -eq 1) {
        Write-Host "Latest Build Reference for Version $mjrvrsn : $buildReference" -ForegroundColor Yellow
    }
	
############################################################################################################
##### Extract latest CU level from build reference
############################################################################################################

    foreach ($reference in $buildReference) {
        $CULevel = $reference.CULevel
        $SPLevel = $reference.SPLevel
        $NameLevel = $reference.NameLevel
    }
	
############################################################################################################
##### Check if server is up-to-date or needs updating
############################################################################################################

    if ($cu -eq $CULevel) {
        Write-Host "$server is up to date. Current CU = $cu - Latest $CULevel" -ForegroundColor Green
    } else {
        # Construct new SQL version format
        $version = "$NameLevel$SPLevel$CULevel" #Example: 2019RTMCU27 | To be passed in the -Version option below.

        # Construct dynamic patch path
        if ($CULevel) { ## for somereason SQL Server 2016 doesn't have a CU that DBATools can retrieve so it brings back NULL.
            Write-Host "$server will be updated to Version: $NameLevel, ServicePack: $SPLevel, Cumulative Update: $CULevel" -ForegroundColor Yellow
            $dynamicPath = "\\SHAREDPATH\SQLServer\$NameLevel\$SPLevel\$CULevel\"
        } else {
            Write-Host "$server will be updated to Version: $NameLevel, ServicePack: $SPLevel" -ForegroundColor Yellow
            $dynamicPath = "\\SHAREDPATH\SQLServer\$NameLevel\$SPLevel\"
        }

        if ($debug -eq 1) {
            Write-Host "Version: $version" -ForegroundColor Yellow
            Write-Host "Dynamic Path: $dynamicPath" -ForegroundColor Yellow
        }
############################################################################################################
######### Start SQL patching using parameters
############################################################################################################

        Update-DbaInstance -ComputerName $server -Path $dynamicPath -Credential $cred -Version $version  -WhatIf #-Restart 

        ## Use the -WhatIf flag to test before executing on production, and -Restart flag on execution
    }
}
############################################################################################################
