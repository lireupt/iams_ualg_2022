Import-Module ActiveDirectory
set-psdebug -off

##Open powershell console with user administrator@cs.local
##runas /netonly /user:administrator@cs.local "C:\Program Files\PowerShell\7\pwsh.exe"
##dsa.msc


# #Teste exemplos a funcionar
# $path = "OU=sales,OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"
# New-ADUser -Name "teste" -GivenName "teste" -Surname "teste" -UserPrincipalName "teste@cs.local" -SamAccountName "teste" -EmployeeID "10000000" -path $path


# 1- Get User form CSV file
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

# 2- Get User form AD
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
        Compare-Object -ReferenceObject $ADUser -DifferenceObject $CSVUser -Property $UniqueId -IncludeEqual
    }
    catch {
        Write-Error -Message $_.Exception.Message
    }  
}

# 4- Get users from CSV and AD with unique parameter  
function Get-UserSyncData {
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
        [string]$UniqueID,
        [Parameter(Mandatory)]
        [string]$OUProperty         
    )

    try {       
            $CompareData = Compare-Users  -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter
            $NewUserId = $CompareData | Where SideIndicator -eq "=>"
            $SyncedUserId = $CompareData | Where SideIndicator -eq "=="
            $RemovedUserId = $CompareData | Where SideIndicator -eq "<="

            $NewSyncUsers = Get-UserFromCsv -FilePath $csvFilePath -Delimiter $csvDelimiter -SyncFieldMap $SyncFieldMap | where $UniqueId -In $NewUserId.$UniqueId
            $SyncedUsers= Get-UserFromCsv -FilePath $csvFilePath -Delimiter $csvDelimiter -SyncFieldMap $SyncFieldMap | where $UniqueId -In $SyncedUserId.$UniqueId
            $RemovedUsers = Get-UsersFromAD -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId| where $UniqueId -In $RemovedUserId.$UniqueId

            #Hash table to set all sync data on place only
            @{
                NewUser = $NewSyncUsers
                SyncUser = $SyncedUsers
                RemovedUser = $RemovedUsers
                Domain = $Domain
                UniqueID = $UniqueID
                OUProperty = $OUProperty
            }
    }
    catch {
        Write-Error Message $_.Exception.Message
    } 
}

# 5- Create a new User
## 5.1 - Create Unique User Name
function New-UserName {
    [CmdletBinding()]
    Param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$Domain,
        [Parameter(Mandatory)]
        [string]$GivenName,
        [Parameter(Mandatory)]
        [string]$SurName      
    )
        #Remove extra caracters and space between names
        [regex]$Pattern="\s|-|'"
        #Iterate to all names to avoid repeat
        $index =1
        do{
            $UserNAme= "$GivenName$($SurName.Substring(0,$index))" -replace $Pattern,""
            $index++
        } while((Get-ADUser -Filter "SamAccountName -like '$UserName'") -and ($UserName -notlike "$GivenName$SurName")) 
            if(Get-ADUser -Filter "SamAccountName -like '$UserName'"){
                throw "No Username available for this user!"
            }else{
                $UserName
            }
}

## 5.2 - Validate existing OU
function Get-ValidateOU {
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
        [string]$OUProperty       
    )

    try {
        $OUNames = Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap | Select-Object -Unique -Property $OUProperty
        foreach($OUName in $OUNames){
            $OUName=$OUName.$OUProperty
            if(-not(Get-ADOrganizationalUnit -Filter "name -eq '$OUName" -Server $Domain)){
                New-ADOrganizationalUnit -Name $OUName -Server $Domain -ProtectedFromAccidentalDeletion $false
            }
        } 
    }
    catch {
        Write-Error Message $_.Exception.Message
    }
    
}

##Create user in AD
function Get-CreateNewUser {
    [CmdletBinding()]
    Param (
        # Parameter help description
        [Parameter(Mandatory)]
        [hashtable]$UserSyncData
             
    )
    
    try {
        $NewUsers = $UserData.NewUser
        foreach($NewUser in $NewUsers){
        #Write-Verbose "Creating new User: {$($NewUser.GivenName) $($NewUser.Surname)}"
        $UserName= New-UserName $NewUSer.GivenName -SurName $NewUser.SurName -Domain $UserData.Domain
        #Write-Verbose "Creating new User: {$($NewUser.GivenName) $($NewUser.Surname)} with usarname : {$username}"
        #Write-Host "$($NewUser.GivenName)" 
        #$OU=Get-ADOrganizationalUnit -Filter "name -eq '($NewUser.$($UserSyncData.OUProperty))'" -Server $UserSyncData.Domain
        

        #If de control de validação de criação de utilizador dentro da property identificada
        if(-not($OU=Get-ADOrganizationalUnit -Filter "name -eq '($NewUser.$($UserSyncData.OUProperty))'" -Server $UserSyncData.Domain)){
            # New-ADOrganizationalUnit -Name $OUName -Server $Domain -ProtectedFromAccidentalDeletion $false
            throw "The organization unit: {$($NewUSer.$($UserSyncData.OUProperty))}"
        } 

        Write-Verbose "Creating new User: {$($NewUser.GivenName) $($NewUser.Surname)} with a username: {$username}, {$ou}"


        #Password
        $Password=-join ((33..126) | Get-Random -Count 12  | ForEach-Object {[char]$_})
        #$SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

        #Hash Table to create NewUser
        @{
            EmployeeID              = $NewUser.EmployeeID
            GivenName               = $NewUser.GivenName
            SurName                 = $NewUser.SurName
            Name                    = $UserName
            SamAccountName          = $UserName
            # UserPrincipalName     = $NewUser.GivenName +" "+ $NewUser.SurName 
            UserPrincipalName       = ("$UserName@$($UserSyncData.Domain)").ToLower()
            AccountPassword         = $Password
            Enabled                 = $true
            Title                   = $NewUser.Title
            Department              = $NewUsers.Department
            #Office                  = $NewUser.Office
            Path                    = $OU.distinguishedName
            Confirm                 = $false
            Server                  = $UserSyncData.Domain 

        }

        New-ADUser @NewADUserParams
        Write-Verbose "Created User: {$($NewUser.Givename))"
  
    }
    }
    catch {
        Write-Error Message $_.Exception.Message
    }
    
}

#Test Error name
#New-UserName -GivenName "Helder" -SurName "O" -Domain $domain

#Permits to Handler field CSV Map Data for any file, by indetify like key() = value
$SyncFieldMap=@{
    Identification_number="EmployeeID"
    first_name="GivenName"
    last_name="SurName"
    jobTitle="Title"
    department="Department"
    #Office = "Office"
}

#Global Variables
$csvFilePath = "C:\CIBERSEGURANCA\Company_GroupSeven1.csv"
$csvDelimiter = ","
$Domain = "cs.local"
#$Domain = "cs.local/User Accounts/Exercicios/test_group7"

#_______________________________________________#
#Unique ID to filter the users
$UniqueId = "EmployeeID"
#_______________________________________________#
#OU property to create or not local inside AD 
$OUProperty = "Department"
#_______________________________________________#

#SCRIPTS
# Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap
# Get-UsersFromAD -SyncFieldMap $SyncFieldMap -UniqueID $UniqueId -Domain $Domain
# Compare-Users  -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter
# $UserData.SyncUser


Get-ValidateOU -SyncFieldMap $SyncFieldMap -Domain $Domain -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter -OUProperty $OUProperty

$UserSyncData = Get-UserSyncData -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter -OUProperty $OUProperty

Get-CreateNewUser -UserSyncData $UserSyncData -Verbose