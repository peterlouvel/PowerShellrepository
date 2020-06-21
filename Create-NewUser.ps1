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
)

.".\IncludePWL.ps1"

$SamAccount         = $UserAccount

$Params             = @("Department", 
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
                # ,"co"
                    )

$CopyUserObject = Get-ADUser -Identity $FromUser -Properties $Params -Server $DomainController

function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Scramble-String([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}

function Create-Password{
    $password = ""
    $password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
    $password += Get-RandomCharacters -length 3 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
    $password += Get-RandomCharacters -length 2 -characters '1234567890'
    $password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'
    $password = Scramble-String $password   
    return $password 
}

function Copy-Groups{
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADObject]$NewAccountObject
        ,
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADObject]$CopyAccountObject
        ,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )

    $counter = 0
    foreach ($UserGroup in $CopyAccountObject.MemberOf){ 
        $GroupName = ($UserGroup -split ",",2)[0]
        # Write-Host $GroupName.Substring(3)

        # Write-Host $counter + " " + $UserGroup

        if ($UserGroup.Contains("DC=au")){
            Write-Host "AU  -- "$GroupName.Substring(3)
            $Server = "au.edmi.local"
        }elseif ($UserGroup.Contains("DC=nz")){
            Write-Host "NZ  -- "$GroupName.Substring(3)
            $Server = "nz.edmi.local"
        }elseif ($UserGroup.Contains("DC=sg")){
            Write-Host "SG  -- "$GroupName.Substring(3) -ForegroundColor Red 
            Continue
            # Don't have access to Singapore Domain
        }else{
            Write-Host "ROOT  -- "$GroupName.Substring(3)
            $Server = "edmi.local"
        }
        
        try{
            Set-ADObject -Identity $UserGroup -Add @{"member"=$NewAccountObject.DistinguishedName} -Server $Server -Credential $Credential
            Write-Host "-- [Worked] $server - $($NewAccountObject.DistinguishedName) " -ForegroundColor Yellow 
            Write-Host "----------------------------------------------------"
        }catch{
            Write-Host "-- Set-ADObject -Identity $UserGroup -Add @{"member"=$NewAccountObject.DistinguishedName} -Server $Server -Credential $Credential" -ForegroundColor Yellow            
            Write-Host "-- [ERROR] $server - $($NewAccountObject.DistinguishedName) " -ForegroundColor Yellow 
            Write-Host "   $($Error[0])" -ForegroundColor Red 
            Write-Host "----------------------------------------------------"
        }
        $counter++
    }
}

function Copy-User{
    param(
        [Parameter(Mandatory=$true)]
        [String]$SamAccount,
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADObject]$CopyAccountObject,
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential
    )
    
    $UserOU             = ($CopyAccountObject.DistinguishedName -split ",",2)[1]
    $Email              = $SamAccount + "" + $End
    $FullNewUserName    = $SamAccount -replace '\.',' '
    $Pos                = $FullNewUserName.IndexOf(" ")
    $GivenName          = $FullNewUserName.Substring(0, $Pos)
    $Surname            = $FullNewUserName.Substring($Pos+1)
    $Department         = $CopyAccountObject.Department
    $Office             = $CopyAccountObject.Office
    $City               = $CopyAccountObject.City
    $PostalCode         = $CopyAccountObject.PostalCode
    $POBox              = $CopyAccountObject.POBox
    $HomePage           = $CopyAccountObject.wWWHomePage
    $Address            = $CopyAccountObject.StreetAddress
    $State              = $CopyAccountObject.State
    $Country            = $CopyAccountObject.Country
    $Company            = $CopyAccountObject.Company
    $Manager            = $CopyAccountObject.Manager
    # $co                 = $CopyAccountObject.co
    $newPass            = Create-Password
    $paramsCreate       = @{  
        Instance            = "$CopyAccountObject" 
        Path                = "$UserOU"
        Name                = "$FullNewUserName"
        SamAccountName      = "$SamAccount"
        GivenName           = "$GivenName" 
        Surname             = "$Surname" 
        DisplayName         = "$FullNewUserName"
        UserPrincipalName   = "$Email"
        Department          = "$Department" 
        Office              = "$Office"
        City                = "$City"
        PostalCode          = "$PostalCode"
        POBox               = "$POBox"
        Title               = "$Title"
        HomePage            = "$HomePage"
        StreetAddress       = "$Address"
        State               = "$State"
        Country             = "$Country"
        Company             = "$Company"
        # co                  = "$co"
    }
    # Write-Host $paramsCreate.Path
    Write-Host
    Write-Host "Creating new user " -NoNewline 
    Write-Host "$FullNewUserName " -ForegroundColor Cyan -NoNewline 
    Write-Host "$SamAccount" -ForegroundColor Green

    Try{
        New-ADUser  @paramsCreate -Credential $Credential -Server $DomainController  
    }Catch{
        Write-Host ""
        Write-Host "-- New-ADUser  @paramsCreate -Credential $Credential" -ForegroundColor Yellow 
        Write-Host "-- [ERROR] $DomainController - $($SamAccount) - $($Error[0])" -ForegroundColor Red 
        Write-Host "----------------------------------------------------"
    }
    $managerName = $manager.Split(",").substring(3)[0]
    Write-Host "Setting users manager to " -ForegroundColor Green -NoNewline
    Write-Host "$managerName" -ForegroundColor Cyan
    Write-Host " --- give it 20 seconds to sync the AD Changes through"
    Start-Sleep -s 20
    Set-ADUser -Identity "$SamAccount" -Replace @{manager="$Manager"} -Credential $Credential -Server $DomainController 
    Write-Host "Setting users password to " -NoNewline  -ForegroundColor Cyan   
    Write-Host "$newPass" -ForegroundColor Green  
    Start-Sleep -s 5
    Set-ADAccountPassword -Identity "$SamAccount" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force) -Credential $Credential -Server $DomainController
    Enable-ADAccount -Identity "$SamAccount" -Credential $Credential -Server $DomainController
}

Copy-User -SamAccount $SamAccount -CopyAccountObject $CopyUserObject -Credential $Cred
Start-Sleep -s 5
Get-ADUser -Identity $SamAccount -Server $DomainController | Set-ADObject -Replace @{co="$Location"} -Credential $Cred -Server $DomainController
Write-Host "-----------------------------------------------------------------------"
# can be qicker if staff is in your local comain, but longer when on the other domain
Write-Host "Waiting 120 seconds for AD systems to update before copying user groups." -ForegroundColor Cyan  
Write-Host "-----------------------------------------------------------------------"
Start-Sleep -s 120

$NewUserObject = Get-ADUser -Identity $SamAccount -Properties $Params -Server $DomainController -Credential $Cred
Write-Host "========================================================================"
Copy-Groups -NewAccountObject $NewUserObject -CopyAccountObject $CopyUserObject -Credential $Cred
