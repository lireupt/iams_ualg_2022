Import-Module ActiveDirectory

##Open powershell console with user administrator@cs.local
##runas /netonly /user:administrator@cs.local "C:\Program Files\PowerShell\7\pwsh.exe"

##Dominio
$Domain="@cs.local"

##Caminho OU
$UserOu="Exercicios,OU=User Accounts,DC=cs,DC=local"
##Caminho file CSV
$ListaNovosUsers=Import-CSV "C:\CIBERSEGURANCA\Company_GroupSeven.csv"

ForEach ($User in $ListaNovosUsers) {

##Variaveis + Atributos
$SID=$User.ID  ##ok

$FullName=$User.first_name + $User.last_name ##ok

$Company=$User.company ##ok

$Department=$User.department ##ok

$Description=$User.employee_type ##ok

$givenName=$User.last_name

$title=$User.title ##ok

$co=$User.nationality ##ok

$countyCode=$User.county ##ok

$City=$User.City ##ok

$mail=$User.personal_email ##ok

$EmployeeType=$User.employeeType ##ok

$telephoneNumber=$User.phone  ##ok

$sAMAccountName=$User.sAMAccountName

$sn=$User.first_name ##ok

$ObjectGUID=$User.ObjectGUID ##ok

$userPrincipalName=$User.sAMAccountName+$Domain

$userPassword=$User.Password 

$AccountExpirationDate=$User.end_contract_date ##OK

##$expire=$null ##ok

New-ADUser -Name $sn -SamAccountName $sAMAccountName  `
            -AccountPassword (ConvertTo-SecureString -AsPlainText 'Pa$$w0rd' -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true 
			-Path $UserOu  `
			-Enabled $True 	 `		
			##-CannotChangePassword $False  `
			-City $City  `
			-Company $Company  `
			-Department $Department  `
			–title $title  `
			–OfficePhone $telephoneNumber  `
			-DisplayName $FullName  `
			-GivenName $givenName  `
			##-Name $FullName  `
			-Surname $sn  `
			-UserPrincipalName $userPrincipalName  `
			-Employee-Type $EmployeeType  `
			-telephoneNumber $telephoneNumber  `
			-EmailAddress $mail  `
			-AccountExpirationDate $AccountExpirationDate  `
			-countyCode $countyCode  `
			-co $co  `
			-ObjectGUID $ObjectGUID  `
			-SID $SID 

}