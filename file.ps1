<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    Get Service Info
#>

# Functions are at the top so the script engine won't complain about not knowing a funciton.
function MyFunction1 {
    
    # Write-Host "Selected: " $LBoxPick.Text
    #.Text = $LBoxPick.Text
}

#region begin GUI{ 
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '400,400'
$Form.text                       = "Service Inspector"
$Form.TopMost                    = $false

$LblPick                         = New-Object system.Windows.Forms.Label
$LblPick.text                    = "Pick Service"
$LblPick.AutoSize                = $true
$LblPick.width                   = 25
$LblPick.height                  = 10
$LblPick.location                = '30,34'
$LblPick.Font                    = 'Microsoft Sans Serif,10'

# $BtnCheckSvc                     = New-Object system.Windows.Forms.Button
# $BtnCheckSvc.text                = "Check Service"
# $BtnCheckSvc.width               = 111
# $BtnCheckSvc.height              = 30
# $BtnCheckSvc.location            = New-Object System.Drawing.Point(231,111)
# $BtnCheckSvc.Font                = 'Microsoft Sans Serif,10'

$LblShow                         = New-Object system.Windows.Forms.Label
# $LblShow.text                    = ""
$LblShow.AutoSize                = $true
$LblShow.width                   = 25
$LblShow.height                  = 10
$LblShow.location                = '27,176'
$LblShow.Font                    = 'Microsoft Sans Serif,10'

$TboxStatus                      = New-Object system.Windows.Forms.TextBox
$TboxStatus.multiline            = $false
$TboxStatus.width                = 314
$TboxStatus.height               = 20
$TboxStatus.location             = '27,196'
$TboxStatus.Font                 = 'Microsoft Sans Serif,15'

$LblCurrent                      = New-Object system.Windows.Forms.Label
$LblCurrent.text                 = "Curent Status"
$LblCurrent.AutoSize             = $true
$LblCurrent.width                = 25
$LblCurrent.height               = 10
$LblCurrent.location             = '30,153'
$LblCurrent.Font                 = 'Microsoft Sans Serif,10'

$LBoxPick                        = New-Object System.Windows.Forms.ListBox
$LBoxPick.width                  = 318
$LBoxPick.height                 = 100
$LBoxPick.location               = '24,62'

$Form.controls.AddRange(@($LBoxPick,$LblPick,$BtnCheckSvc,$TboxStatus,$LblCurrent,$LblShow))

#endregion GUI }

$LBoxPick.Add_SelectedValueChanged({ MyFunction1 $this $_  })

$Servs = Get-Service | Select-Object -Property name
$LBoxPick.Items.AddRange($Servs.name)

[void]$Form.ShowDialog()