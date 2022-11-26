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
$ListaNovosUsers=Import-CSV "C:\CIBERSEGURANCA\Company_GroupSeven1.csv"

ForEach ($User in $ListaNovosUsers) {

##Variaveis + Atributos
$SID=$User.ID  ##ok

#UserPrincipalName, SAMAccountName, GivenName, Sn, DisplayName
$userPrincipalName=$User.sAMAccountName+$Domain
$sAMAccountName=$User.Identification_number
$snName=$User.last_name
$givenName=$User.first_name
$userDisplaylName=$User.first_name + $User.last_name

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
$companyMail= $User.last_name + '.' + $User.first_name + '@' + $UserCompany + '.com'

#AccountExpirationDate
$accountExpirationDate= $User.end_contract_date - 1


#$ObjectGUID=$User.ObjectGUID ##ok

##$expire=$null ##ok

#Create teste organization
#New-ADOrganizationalUnit -name "test1" -Path "OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"


New-ADOrganizationalUnit -name $department -Path "OU=test_group7,OU=Exercicios,OU=User Accounts,DC=cs,DC=local"




New-ADUser  -name 'Helder'` #ok
            -AccountName '12345'  ` #Não funciona
            -Enabled $true `
            -Path $UserOu  #ok


New-ADUser -Name $sn -SamAccountName $sAMAccountName  `
            -AccountPassword (ConvertTo-SecureString -AsPlainText 'Pa$$w0rd' -Force) `
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


            

}