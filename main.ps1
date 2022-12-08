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
            [string]$UniqueID,
            [Parameter(Mandatory)]
            [string]$UserOu
            
        )
        
        #EmployeeId gone be us Identifier Unique to employer, can been changed if another parameter
        try {
                    Get-Aduser -Filter "$UniqueId -like '*'" -Server $Domain -Properties @($SyncFieldMap.Values) -SearchBase $UserOu

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
        [string]$UniqueID,
        [Parameter(Mandatory)]
        [string]$UserOu
        
    )
    try {
        $CSVUser = Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap
        $ADUser = Get-UsersFromAD -SyncFieldMap $SyncFieldMap -UniqueID $UniqueId -Domain $Domain -UserOu $UserOu
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
        [string]$OUProperty,
        [Parameter(Mandatory)]
        [string]$UserOu       
    )

    try {       
            $CompareData    = Compare-Users  -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter -UserOu $UserOu
            $NewUserId      = $CompareData | Where SideIndicator -eq "=>"
            $SyncedUserId   = $CompareData | Where SideIndicator -eq "=="
            $RemovedUserId  = $CompareData | Where SideIndicator -eq "<="

            $NewSyncUsers   = Get-UserFromCsv -FilePath $csvFilePath -Delimiter $csvDelimiter -SyncFieldMap $SyncFieldMap       | where $UniqueId -In $NewUserId.$UniqueId
            $SyncedUsers    = Get-UserFromCsv -FilePath $csvFilePath -Delimiter $csvDelimiter -SyncFieldMap $SyncFieldMap       | where $UniqueId -In $SyncedUserId.$UniqueId
            $RemovedUsers   = Get-UsersFromAD -SyncFieldMap $SyncFieldMap -Domain $Domain -UserOu $UserOu -UniqueID $UniqueId   | where $UniqueId -In $RemovedUserId.$UniqueId

            #Hash table to set all sync data on place only
            @{
                NewUser     = $NewSyncUsers
                SyncUser    = $SyncedUsers
                RemovedUser = $RemovedUsers
                Domain      = $Domain
                UniqueID    = $UniqueID
                OUProperty  = $OUProperty
                UserOu      = $UserOu
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
        [string]$OUProperty,
        [Parameter(Mandatory)]
        [string]$UserOu  

    )

    try {
        $OUNames = Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap | Select-Object -Unique -Property $OUProperty
        foreach($OUName in $OUNames){
            $OUName=$OUName.$OUProperty
            # if(-not(Get-ADOrganizationalUnit -Filter * -Server $Domain -SearchBase $UserOu)){
             if(-not(Get-ADOrganizationalUnit -Filter "name -eq '$OUName" -Server $Domain -SearchBase $UserOu)){
             New-ADOrganizationalUnit -Name $OUName -Server $Domain -ProtectedFromAccidentalDeletion $false -Path $UserOu
            }
        } 
    }
    catch {
        Write-Error Message $_.Exception.Message
    }  
}

## 5.3 - Create user in AD
function Get-CreateNewUser {
    [CmdletBinding()]
    Param (
        # Parameter help description
        [Parameter(Mandatory)]
        [hashtable]$UserSyncData
             
    )
    
    try {
        $NewUsers = $UserSyncData.NewUser
        foreach($NewUser in $NewUsers){
        #Write-Verbose "Creating new User: {$($NewUser.GivenName) $($NewUser.Surname)}"
        $UserName= New-UserName $NewUSer.GivenName -SurName $NewUser.SurName -Domain $UserSyncData.Domain

        #If de control de validação de criação de utilizador dentro da property identificada
        if(-not($OU = Get-ADOrganizationalUnit -Filter "name -eq '$($NewUser.$($UserSyncData.OUProperty))'" -Server $UserSyncData.Domain -SearchBase $UserSyncData.UserOu)){
                throw "The organization unit: $($NewUSer.$($UserSyncData.OUProperty))"
        } 

        Write-Verbose "Creating new User: {$($NewUser.GivenName) $($NewUser.Surname)} with a username: {$UserName}, {$OU}"

        #Password
        $Password=-join ((33..126) | Get-Random -Count 12  | ForEach-Object {[char]$_})
        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        
        
        #Rever esta situação, não está a criar a partir da hastable !!!!
        #Hash Table to create NewUser
        # @{
        #     EmployeeID              = $NewUser.EmployeeID
        #     GivenName               = $NewUser.GivenName
        #     SurName                 = $NewUser.SurName
        #     Name                    = $UserName
        #     SamAccountName          = $UserName
        #     # UserPrincipalName     = $NewUser.GivenName +" "+ $NewUser.SurName 
        #     UserPrincipalName       = ($UserName + "@" + $($UserSyncData.Domain)).ToLower()
        #     AccountPassword         = $SecurePassword.Password
        #     Enabled                 = $true
        #     Title                   = $NewUser.Title
        #     Department              = $NewUser.Department
        #     Company                 = "Grupo 7"
        #     EmployeeNumber          = $NewUser.EmployeeID
        #     #Office                  = $NewUser.Office
        #     Path                    = $OU.distinguishedName
        #     Confirm                 = $false
        #     Server                  = $UserSyncData.Domain 
        # }
        #New-ADUser @$NewADUserParams

        #Create a new AD User tradicional way   
        New-ADUser -Name $UserName -GivenName $NewUser.GivenName -AccountPassword $SecurePassword -Surname $NewUser.SurName -UserPrincipalName ("$UserName@$($UserSyncData.Domain)").ToLower() -SamAccountName $UserName -EmployeeID $NewUser.EmployeeID -path $OU.distinguishedName -Company "Grupo 7" -Title $NewUser.Title -Department $NewUser.Department -Enabled $true -ChangePasswordAtLogon $true -EmailAddress $NewUser.otherMailBox -AccountExpirationDate $NewUser.AccountExpirationDate -MobilePhone $NewUser.MobilePhone       
        Write-Verbose "Created User: $($NewUser.GivenName)"
    }
    }
    catch {
        Write-Error Message $_.Exception.Message
    }    
}

## 5.4 - Check User-Names
function Get-CheckUserName {
    [CmdletBinding()]
    Param (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$Domain,
        [Parameter(Mandatory)]
        [string]$UserOu,
        [Parameter(Mandatory)]
        [string]$GivenName,
        [Parameter(Mandatory)]
        [string]$SurName,
        [Parameter(Mandatory)]
        [string]$CurrentuserName        
    )
        #Remove extra caracters and space between names
        [regex]$Pattern="\s|-|'"
        #Iterate to all names to avoid repeat
        $index =1
        do{
            $UserNAme= "$GivenName$($SurName.Substring(0,$index))" -replace $Pattern,""
            $index++
        } while((Get-ADUser -Filter "SamAccountName -like '$UserName'" -Server $Domain -SearchBase $UserOu) -and ($UserName -notlike "$GivenName$SurName") -and ($UserName -notlike $CurrentuserName)) 
            if((Get-ADUser -Filter "SamAccountName -like '$UserName'" -Server $Domain -SearchBase $UserOu) -and ($UserName -notlike $CurrentuserName)){
                throw "No Username available for this user!"
            }else{
                $UserName
            }
} 

#Get-CheckUserName -GivenName "Ernest" -SurName "Staller" -CurrentuserName "ErnestS" -Domain $Domain -UserOu $UserOu

## 6.2 - Change fields in AD
# function Sync-ExistingUsers {
#     [CmdletBinding()]
#     Param (
#         # Parameter help description
#         [Parameter(Mandatory)]
#         [hashtable]$UserSyncData       
#     )
#     $SyncedUsers= $UserSyncData.SyncUser
#     foreach($SyncedUser in $SyncedUsers){
#         #Write-Verbose "Loading data for $($SyncedUser.GivenName)"
#         $ADUsers = Get-ADUser -Filter "$($UserSyncData.UniqueID) -eq $($SyncedUser.$($UserSyncData.UniqueID))" -Server $UserSyncData.Domain -SearchBase $UserSyncData.UserOu -Properties *
#         if(-not($OU = Get-ADOrganizationalUnit -Filter "name -eq '$($SyncedUser.$($UserSyncData.OUProperty))'" -Server $UserSyncData.Domain -SearchBase $UserSyncData.UserOu)){
#             throw "The organization unit: $($NewUSer.$($SyncedUser.$($UserSyncData.OUProperty)))"
#         }  
#         #Write-Verbose "The user currently in  $($ADUser.DistinguishedName) but shoul be $OU"
#         # #Change OU
#         Write-Verbose "The name $($ADUser.DistinguishedName)"
#         if(($ADUsers.DistinguishedName.Split(",")[1..$($ADUser.DistinguishedName.Length)] -join ",") -ne ($OU.DistinguishedName)){
#             #Write-Verbose "The name need to be changed"
#             Get-ADUser -Identity $ADUsers | Move-ADObject -TargetPath  $OU.DistinguishedName
#            # Move-ADObject -Identity $ADUser -TargetPath $OU.DistinguishedName -Server $UserSyncData.Domain -PassThru $UserOu
#         }
#         # $ADUser = Get-ADUser -Filter "$($UserSyncData.UniqueID) -eq $($SyncedUser.$($UserSyncData.UniqueID))" -Server $UserSyncData.Domain -SearchBase $UserSyncData.UserOu -Properties *
#         # $UserName = Get-CheckUserName -GivenName $SyncedUser.GivenName -SurName $SyncedUser.SurName -CurrentuserName $ADUser.SamAccountName -Domain $UserSyncData.Domain -UserOu $UserSyncData.UserOu     
#         # if($ADUser.SamAccountName -notlike $UserName){
#         #     Write-Verbose "Username nedds to be changed"
#         #     Set-ADUser -Identity $ADUser -Replace @{UserPrincipalName="$UserName@$($UserSyncData.Domain)"} -Server $UserSyncData.Domain
#         #     Set-ADUser -Identity $ADUser -Replace @{SamAccountName="$UserName"} -Server $UserSyncData.Domain
#         #     Rename-ADObject -Identity $ADUser -NewName $UserName -Server $UserSyncData.Domain
#         # }
#     }   
# }

## 6.3 - Remove




#Test Error name


#Permits to Handler field CSV Map Data for any file, by indetify like key() = value
$SyncFieldMap=@{
    ID                  ="EmployeeID"
    first_name          ="GivenName"
    last_name           ="SurName"
    Employee_type       ="Title"
    department          ="Department"
    end_contract_date   ="AccountExpirationDate"
    personal_email      ="otherMailBox"
    phone               ="MobilePhone"
    #Office = "Office"
}

#Global Variables
$csvFilePath        = "C:\CIBERSEGURANCA\Company_GroupSeven1.csv"
$csvDelimiter       = ","
$Domain             = "cs.local"

#____________________________________________________________#
#Local to put the your users group organization
$UserOu         = "OU=Grupo 7,OU=User Accounts,DC=cs,DC=local"
#____________________________________________________________#
#Unique ID to filter the users
$UniqueId       = "EmployeeID"
#____________________________________________________________#
#OU property to create or not inside AD 
$OUProperty     = "Department"
#____________________________________________________________#

#SCRIPTS
# Get-UserFromCsv -FilePath $csvFilePath  -Delimiter $csvDelimiter  -SyncFieldMap $SyncFieldMap
# Get-UsersFromAD -SyncFieldMap $SyncFieldMap -UniqueID $UniqueId -Domain $Domain -UserOu $UserOu
# Compare-Users  -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter
# $UserData.SyncUser


Get-ValidateOU -SyncFieldMap $SyncFieldMap -Domain $Domain -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter -OUProperty $OUProperty -UserOu $UserOu

$UserSyncData = Get-UserSyncData -SyncFieldMap $SyncFieldMap -Domain $Domain -UniqueID $UniqueId -CsvFilePath $csvFilePath -csvDelimiter $csvDelimiter -OUProperty $OUProperty -UserOu $UserOu 

Get-CreateNewUser -UserSyncData $UserSyncData -Verbose

# Sync-ExistingUsers -UserSyncData $UserSyncData -Verbose



$RemovedUsers = $UserSyncData.RemovedUser
#$GetAdUsers = Get-Aduser -Filter "$UniqueId -like '*'" -Server $Domain -Properties @($SyncFieldMap.Values) -SearchBase $UserOu

foreach($RemovedUser in $RemovedUsers){
    $RemoverUsertest = $RemovedUser.GivenName

    $ADUserR = Get-Aduser $RemoverUsertest  -Server $Domain -Properties@($SyncFieldMap.Values) -SearchBase $UserOu
    
}