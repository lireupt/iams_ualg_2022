Import-Module ActiveDirectory
set-psdebug -off

##Open powershell console with user administrator@cs.local
##runas /netonly /user:administrator@cs.local "C:\Program Files\PowerShell\7\pwsh.exe"
##dsa.msc

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
        Write-Error -Message $_.Exception.Message
    }  
}


# 2- Create New-ADUser
function Get-UsersFromAD{
[CmdletBinding()]
        Param (
            # Parameter help description
            [Parameter(Mandatory)]
            [hashtable]$SyncFieldMap,
            [Parameter(Mandatory)]
            [string]$Domain,
            # => Rever esta situação
            [Parameter(Mandatory)]
            [string]$UniqueID
            
        )
        
        #EmployeeId gone be us Identifier Unique to employer, can been changed if another parameter
        try {
                    Get-Aduser -Filter "$UniqueId -like '*'" -Server $Domain -Properties @($SyncFieldMap.Values)
                }
                catch {
                    Write-Error -Message $_.Exception.Message
                }
} 




 New-ADUser -Name "luciano123" -GivenName "luciano" -Surname "teste" -UserPrincipalName "luciano@cs.local" -SamAccountName "lucianoH" -EmployeeID "00000000"

 Get-ADUser -Identity luciano123 -Server "cs.local" -Properties *
#  Get-AdUser -Filter{$uniqueId -like "helder"} -Server "cs.local"  
 Get-AdUser -Filter "$UniqueId -like '*'" -Server "cs.local" 


$UniqueId = "EmployeeID"


# 3- Compare those


function Compare-Users {
    [CmdletBinding()]
    Param (
        # Parameter help description
        [Parameter(Mandatory)]
        [hashtable]$SyncFieldMap,
        [Parameter(Mandatory)]
        [string]$Domain,
        [Parameter(Mandatory)]
        [string]$CsvFilePath,
        [Parameter()]
        [string]$csvDelimiter=",",
        [Parameter(Mandatory)]
        [string]$UniqueID
        
    )
    try {
        $CSVUser = Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap
        $ADUser = Get-UsersFromAD -SyncFieldMap $SyncFieldMap -UniqueID $UniqueId -Domain $Domain
        Compare-Object -ReferenceObject $ADUser -DifferenceObject $CSVUser -Property $UniqueId
    }
    catch {
        Write-Error -Message $_.Exception.Message
    }  
}

#Permits to Handler field CSV Map Data for any file, by indetify like key() = value
$SyncFieldMap=@{
    Identification_number="EmployeeID"
    first_name="Name"
    last_name="SurName"
    jobTitle="Title"
    department="Department"
}

#Global Variables
$csvFilePath = "C:\CIBERSEGURANCA\Company_GroupSeven1.csv"

##caminho casa
#$csvFilePath = "D:\Projects\iams_ualg_2022\Company_GroupSeven1.csv"

$csvDelimiter = ","
$Domain = "cs.local"
#$Domain = "cs.local/User Accounts/Exercicios/test_group7"
$UniqueId = "EmployeeID" 
 


#SCRIPTS
# Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap
# Get-UsersFromAD -SyncFieldMap $SyncFieldMap -UniqueID $UniqueId -Domain $Domain

Compare-Users  -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter




