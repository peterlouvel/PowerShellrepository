<#
.SYNOPSIS
    Create a new User and copy other users groups and info
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> Create-NewUser -UserName "FirstName LastName" -FromUser "existing.user" -Title "New Users Job Title" -UsersDomain "au"
    Creates user "new.user and copies some info from "existing.user" 
.INPUTS
    .
.OUTPUTS
    .
.NOTES
    Domain can be
        au
        nz
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UserName
    ,[Parameter(Mandatory=$true)]
    [string]$FromUser
    ,[Parameter(Mandatory=$true)]
    [string]$Title
    ,[Parameter(Mandatory=$false)]
    [string]$UsersDomain = "z"
    ,[Parameter(Mandatory=$true)]
    [string]$UserDepartment
)

$DeparmentFile = ".\UserDepartment\$UserDepartment.txt"

[String] ${stYourDomain},[String]  ${stYourAccount} = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.split("\")
$AdminAccount = $stYourAccount + "_"

if ($UsersDomain -eq "z"){
    $UsersDomain=$stYourDomain
}

if ($UsersDomain -eq "au"){
    $End = "@edmi.com.au"
    $DomainController = "AuBneDC12.au.edmi.local"
    $FQD = "au.edmi.local"
    $AdminAccount1 = "au\"+$AdminAccount
    $Location = "Australia"
} elseif ($UsersDomain -eq "nz"){
    $End = "@edmi.co.nz"
    # $DomainController = "NZwlgDC3.nz.edmi.local"
    $DomainController = "NzBneDC5.nz.edmi.local"
    $FQD = "nz.edmi.local"
    $AdminAccount1 = "nz\"+$AdminAccount
    $Location = "New Zealand"
} elseif ($UsersDomain -eq "uk"){    #Not working for some reason
    $End = "@edmi-meters.com"
    # $DomainController = "UkRdgDC1.uk.edmi.local"
    $DomainController = "UkBneDC2.uk.edmi.local"
    $FQD = "uk.edmi.local"
    $AdminAccount1 = "uk\"+$AdminAccount
    $Location = "United Kingdom"
} elseif ($UsersDomain -eq "sg"){     #Not working for some reason
    $End = "@edmi-meters.com"
    # $DomainController = "SgBneDC1.sg.edmi.local"
    $DomainController = "sg.edmi.local"
    $FQD = "sg.edmi.local"
    $AdminAccount1 = "sg\"+$AdminAccount
    $Location = "Singapore"
} else {
    Write-Host
    Write-Host "Domain should be AU, NZ, UK, SG" -ForegroundColor Red 
    # $ErrorActionPreference = "SilentlyContinue"
    exit
}

if ($null -eq $Cred){ $Cred = Get-Credential $AdminAccount1 } 

$UserName       = (Get-Culture).TextInfo.ToTitleCase($UserName.ToLower()) 
$UserAccount    = $UserName -replace ' ','.'
$UserEmail      = $UserAccount.ToLower() + $End
$SamAccount     = $UserAccount

$Params = @("Department", 
    "Office", 
    "physicalDeliveryOfficeName", 
    "City", 
    "wWWHomePage", 
    "PostalCode", 
    "POBox", 
    "postOfficeBox", 
    "DistinguishedName",
    "StreetAddress",
    "State",
    "Country",
    "Company",
    "Manager",
    "MemberOf"
)

$CopyUserObject = Get-ADUser -Identity $FromUser -Properties $Params -Server $DomainController

function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Set-ScrambledString([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}

function Set-NewPassword{
    $password = ""
    $password = Get-RandomCharacters -length 5 -characters 'abcdefghkmnprstuvwxyz'
    $password += Get-RandomCharacters -length 3 -characters 'ABCDEFGHKMNPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 2 -characters '23456789'
    $password += Get-RandomCharacters -length 1 -characters '$()=?}][{#*'
    $password = Set-ScrambledString $password   
    return $password 
}

function Copy-Groups{
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADObject]$NewAccountObject
        ,[Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADObject]$CopyAccountObject
        ,[Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )
    $counter = 0
    foreach ($UserGroup in $CopyAccountObject.MemberOf){ 
        $GroupName = ($UserGroup -split ",",2)[0]
        Write-Host "GroupName --> $GroupName"
        Write-Host "UserGroup --> $UserGroup"
        if ($UserGroup.Contains("DC=au")){
            Write-Host "AU  -- "$GroupName.Substring(3)
            $Server = "au.edmi.local"
        }elseif ($UserGroup.Contains("DC=nz")){
            Write-Host "NZ  -- "$GroupName.Substring(3)
            $Server = "nz.edmi.local"
        }elseif ($UserGroup.Contains("DC=uk")){
            Write-Host "UK  -- "$GroupName.Substring(3)
            $Server = "uk.edmi.local"
        }elseif ($UserGroup.Contains("DC=sg")){
            Write-Host "SG  -- "$GroupName.Substring(3)
            $Server = "SG.edmi.local"
        }else{
            Write-Host "ROOT  -- "$GroupName.Substring(3)
            $Server = "edmi.local"
        }
        # try{
        #     Set-ADObject -Identity $UserGroup -Add @{"member"=$NewAccountObject.DistinguishedName} -Server $Server -Credential $Credential
        #     Write-Host "-- [Worked] $server - $($NewAccountObject.DistinguishedName) " -ForegroundColor Yellow 
        #     Write-Host "----------------------------------------------------"
        # }catch{
        #     Write-Host "-- Set-ADObject -Identity $UserGroup -Add @{"member"=$NewAccountObject.DistinguishedName} -Server $Server -Credential $Credential" -ForegroundColor Yellow
        #     Write-Host "-- [ERROR] $server - $($NewAccountObject.DistinguishedName) " -ForegroundColor Cyan
        #     Write-Host "   $($Error[0])" -ForegroundColor Red
        #     Write-Host "----------------------------------------------------"
        # }
        $counter++
    }
}

function Copy-User{
    param(
        [Parameter(Mandatory=$true)]
        [String]$SamAccount,
        # [Parameter(Mandatory=$true)]
        # [Microsoft.ActiveDirectory.Management.ADObject]$CopyAccountObject,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )
    # Write-Host "Account object $CopyAccountObject"
    # Write-Host $CopyAccountObject.Office
    # $UserOU             = ($CopyAccountObject.DistinguishedName -split ",",2)[1]
    $Email              = $SamAccount + "" + $End
    $FullNewUserName    = $SamAccount -replace '\.',' '
    $Pos                = $FullNewUserName.IndexOf(" ")
    $GivenName          = $FullNewUserName.Substring(0, $Pos)
    $Surname            = $FullNewUserName.Substring($Pos+1)
    # $Department         = $CopyAccountObject.Department
    # $Office             = $CopyAccountObject.Office
    # $City               = $CopyAccountObject.City
    # $PostalCode         = $CopyAccountObject.PostalCode
    # $POBox              = $CopyAccountObject.POBox
    # $HomePage           = $CopyAccountObject.wWWHomePage
    # $Address            = $CopyAccountObject.StreetAddress
    # $State              = $CopyAccountObject.State
    # $Country            = $CopyAccountObject.Country
    # $Company            = $CopyAccountObject.Company
    # $Manager            = $CopyAccountObject.Manager
    $newPass            = Set-NewPassword

    $paramDepartment    = Import-PowerShellDataFile $DeparmentFile
    
    $paramsCreate       = @{  
        Name                = "$FullNewUserName"
        SamAccountName      = "$SamAccount"
        GivenName           = "$GivenName" 
        Surname             = "$Surname" 
        DisplayName         = "$FullNewUserName"
        UserPrincipalName   = "$Email"
        Title               = "$Title"
        Path                = $paramDepartment.Path
        Department          = $paramDepartment.Department
        Office              = $paramDepartment.Office
        City                = $paramDepartment.City
        PostalCode          = $paramDepartment.PostalCode
        POBox               = $paramDepartment.POBox
        HomePage            = $paramDepartment.HomePage
        StreetAddress       = $paramDepartment.StreetAddress
        State               = $paramDepartment.State
        Country             = $paramDepartment.Country
        Company             = $paramDepartment.Company
    }

    # $paramsCreate       = @{  
    #     Instance            = "$CopyAccountObject" 
    #     Path                = "$UserOU"
    #     Name                = "$FullNewUserName"
    #     SamAccountName      = "$SamAccount"
    #     GivenName           = "$GivenName" 
    #     Surname             = "$Surname" 
    #     DisplayName         = "$FullNewUserName"
    #     UserPrincipalName   = "$Email"
    #     Department          = "$Department" 
    #     Office              = "$Office"
    #     City                = "$City"
    #     PostalCode          = "$PostalCode"
    #     POBox               = "$POBox"
    #     Title               = "$Title"
    #     HomePage            = "$HomePage"
    #     StreetAddress       = "$Address"
    #     State               = "$State"
    #     Country             = "$Country"
    #     Company             = "$Company"
    # }


# # Create a hashtable-literal representation and save it to file settings.txt
# @"
# @{
# $(
#   ($paramsCreate.GetEnumerator() |
#     ForEach-Object { 
#       "  {0}={1}" -f $_.Name, (
#         $_.Value.ForEach({ 
#           (("'{0}'" -f ($_ -replace "'", "''")), $_)[$_.GetType().IsPrimitive] 
#          }) -join ','
#       )
#     }
#   ) -join "`n"
# )
# }
# "@ > settings.txt

# Write-Host "done"



# $paramsCreate.Keys | ForEach-Object {
#     "The value of '$_' is: $($paramsCreate[$_])"
# }

$paramsCreate

 Start-Sleep -s 2000

    Write-Host
    Write-Host "Creating new user " -NoNewline 
    Write-Host "$FullNewUserName " -ForegroundColor Cyan -NoNewline 
    Write-Host "$SamAccount" -ForegroundColor Green
    # Start-Sleep -s 200
    Try{
        New-ADUser  @paramsCreate -Credential $Credential -Server $DomainController  
    }Catch{
        Write-Host ""
        Write-Host "-- New-ADUser  @paramsCreate -Credential $Credential" -ForegroundColor Yellow 
        Write-Host "-- [ERROR] $DomainController - $($SamAccount) - $($Error[0])" -ForegroundColor Red 
        Write-Host "----------------------------------------------------"
    }
    Write-Host " --- give it 20 seconds to sync the AD Changes"
    Start-Sleep -s 20
    Write-Host "Manager --> $manager"
    if ($manager){
        $managerName = $manager.Split(",").substring(3)[0]
        Write-Host "Setting users manager to " -ForegroundColor Green -NoNewline
        Write-Host "$managerName" -ForegroundColor Cyan
        Set-ADUser -Identity "$SamAccount" -Replace @{manager="$Manager"} -Credential $Credential -Server $DomainController 
    }
    Write-Host "Setting users password to " -NoNewline  -ForegroundColor Cyan   
    Write-Host "$newPass" -ForegroundColor Green  
    Start-Sleep -s 5
    Set-ADAccountPassword -Identity "$SamAccount" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force) -Credential $Credential -Server $DomainController
    Enable-ADAccount -Identity "$SamAccount" -Credential $Credential -Server $DomainController
}

# Copy-User -SamAccount $SamAccount -CopyAccountObject $CopyUserObject -Credential $Cred
Copy-User -SamAccount $SamAccount -Credential $Cred
Start-Sleep -s 5
Get-ADUser -Identity $SamAccount -Server $DomainController | Set-ADObject -Replace @{co="$Location"} -Credential $Cred -Server $DomainController
Write-Host "-----------------------------------------------------------------------"
# can be qicker if staff is in your local domain, but longer when on the other domain
Write-Host "Waiting 120 seconds for AD systems to update before copying user groups." -ForegroundColor Cyan  
Write-Host "-----------------------------------------------------------------------"
# Start-Sleep -s 120

$NewUserObject = Get-ADUser -Identity $SamAccount -Properties $Params -Server $DomainController -Credential $Cred
Write-Host "========================================================================"
Copy-Groups -NewAccountObject $NewUserObject -CopyAccountObject $CopyUserObject -Credential $Cred
Write-Host "$SamAccount" -ForegroundColor Green