Import-Module ActiveDirectory

##Open powershell console with user administrator@cs.local
##runas /netonly /user:administrator@cs.local "C:\Program Files\PowerShell\7\pwsh.exe"

##Dominio
$Domain="@cs.local"

##Caminho OU
#$UserOu="Exercicios,OU=User Accounts,DC=cs,DC=local"
$UserOu="OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"
#cs.local/User Accounts/Exercicios/test_group7
##Caminho file CSV
$ListaNovosUsers=Import-CSV "C:\CIBERSEGURANCA\Company_GroupSeven.csv"



#teste functions
function Get-SamAccountName {

     $SamaccountnamePart1 = $User.first_name.ToLower() + $User.last_name.Substring(0,2).ToLower()
     $SamaccountnamePart2 = Get-Random -Minimum 100 -Maximum 999
     #$SamaccountnamePart3 = -join ((65..90) | Get-Random -Count 1  | ForEach-Object {[char]$_})
     #$Samaccountname = -join ($SamaccountnamePart1, $SamaccountnamePart2, $SamaccountnamePart3)
     $Samaccountname = -join ($SamaccountnamePart1,$SamaccountnamePart2)
    return $Samaccountname
}

Get-SamAccountName

ForEach ($User in $ListaNovosUsers) {
#Test fields
#Id user
$SID=$User.ID  ##ok
    
#UserPrincipalName, SAMAccountName, GivenName, Sn, DisplayName
$userPrincipalName=$User.last_name+$Domain
$sAMAccountName=Get-SamAccountName
$snName=$User.last_name
$givenName=$User.first_name
$userDisplaylName=$User.first_name + " " + $User.last_name
$userPassword= -join ((33..126) | Get-Random -Count 12  | ForEach-Object {[char]$_})


#Title, Department, Company
$employeeTittle=$User.jobTitle ##ok
$department=$User.department ##ok
$userCompany='GroupSevenCompany'

#EmployeeID, EmployeeNumber, EmployeeType
$employeeId=$User.ID ##ok
$employeeNumber=$User.Identification_number ##ok
$employeeType=$User.employeeType ##ok

#Mail,OtherMailbox
$mail=$User.personal_email ##ok
$companyMail= $User.last_name.ToLower() + '.' + $User.first_name.ToLower() + '@' + $UserCompany.ToLower() + '.com'

#AccountExpirationDate
$accountExpirationDate= $User.end_contract_date

echo $SID $userPrincipalName $sAMAccountName $snName $givenName $userPassword $userDisplaylName $employeeTittle $department $userCompany $employeeId $employeeNumber $employeeType $mail $companyMail $accountExpirationDate

}



#$ObjectGUID=$User.ObjectGUID ##ok

##$expire=$null ##ok

#FUNCTIONS


#Create teste organization
#New-ADOrganizationalUnit -name "test1" -Path "OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"
New-ADOrganizationalUnit -name $department -Path "OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"



New-ADUser  -name 'Helder'` #ok
            #-AccountName '12345'  ` #Não funciona
            -AccountPassword $userPassword `
            -Enabled $true `
            -Path $UserOu  #ok


New-ADUser -Name $sn -SamAccountName $sAMAccountName  `
            -AccountPassword (ConvertTo-SecureString -AsPlainText ($userPassword) -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true 
			-Path $UserOu  `
			-Enabled $True 	 `
            -SID $SID 
            -userPrincipalName $userPrincipalName  `
            -sn $snName  `
            -givenName $givenName  `
            -displayName $userDisplaylName  `
            -title $employeeTittle  `
            -department $Department  `
			-Company $Company  `
			-employeeID $employeeId  `
            -employeeNumber $employeeNumber  `
			-employeeType $EmployeeType  `
            -mail $companyMail  `
			-otherMailBox $mail  `
			-accountExpirationDate $AccountExpirationDate  
			#-ObjectGUID $ObjectGUID  


            

