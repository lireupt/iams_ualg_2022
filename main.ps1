Import-Module ActiveDirectory

##Open powershell console with user administrator@cs.local
##runas /netonly /user:administrator@cs.local "C:\Program Files\PowerShell\7\pwsh.exe"
##dsa-msc

# 1- Load data from data cvs file
#Make array with hash tables, to hanlder the diferent headers on csv file
# Import-Csv -Path "C:\projects\iams_ualg_2022\Company_GroupSeven1.csv" -Delimiter "," | Select-Object -Property `
# @{Name="EmployeeId"; Expression={$_.Identification_number}},
# @{Name="GivenName"; Expression={$_.first_name}},
# @{Name="Surname"; Expression={$_.last_name}},
# @{Name="Title"; Expression={$_.jobTitle}},
# @{Name="Depatment"; Expression={$_.department}}
# $SyncPropreties=$SyncFieldMap.GetEnumerator()
# $Properties = foreach ($Property in $SyncPropreties) {
#     @{Name = $Property.Value;Expression=[scriptblock]::Create("`$_.$($Property.Key)")}
# }
# Import-Csv -Path "C:\projects\iams_ualg_2022\Company_GroupSeven1.csv" -Delimiter "," | Select-Object -Property $Properties

## Get User form CSV file
function Get-UserFromCsv {
        [CmdletBinding()]
        Param (
            # Parameter help description
            [Parameter(Mandatory)]
            [string]$FilePath,
            [Parameter(Mandatory)]
            [string]$Delimiter,
            [Parameter(Mandatory)]
            [hashtable]$SyncFieldMap
        )

    try {
        $SyncPropreties=$SyncFieldMap.GetEnumerator()
        $Properties = foreach ($Property in $SyncPropreties) {
            @{Name = $Property.Value;Expression=[scriptblock]::Create("`$_.$($Property.Key)")}  
    }
    
    Import-Csv -Path $FilePath -Delimiter $Delimiter | Select-Object $Properties

    }
    catch {
        Write-Error $._Exception.Message
    }  
}

#Permits to Handler field CSV Map Data for any file, by indetify like key() = value
$SyncFieldMap=@{
    identification_number="EmployeeId"
    first_name="GiveName"
    last_name="SurName"
    jobTitle="Title"
    department="Department"
}



#SCRIPTS
Get-UserFromCsv -FilePath "C:\projects\iams_ualg_2022\Company_GroupSeven1.csv" -Delimiter ","  -SyncFieldMap $SyncFieldMap






