#Author:            N.Verkooij
#Author Revision:   M. van den Berg - 12-10-2022

<#
.SYNOPSIS
    Dit script doet een diskspace check en verstuurd een email als de vrije ruimte onder de treshhold uitkomt. 
.DESCRIPTION
    Dit script controleerd  
    wijzig het domein afhankelijk vanwaar dit script draait. 
    Zet machines die niet meer hoeven te worden gecontroleerd in de exceptlist.txt 
    het script checkt ad op de servernamen en haalt hier de servers op de execptlist uit 
    vervolgens controleerd het script de connectie en als die er is dan checkt het de vrije diskruimte 
    als deze diskruimte onder de mingbtreshold komt stuurt het script een email naar topdesk 
.PARAMETER Threshold
    This specifies the ammount of free disk space required, the default is 2GB. 
.PARAMETER Domain
    Specificeer het domein waar het om gaat. 
.PARAMETER to
    This specifies the email address TO whom the email needs to be sent
.PARAMETER from
    This specifies the email address FROM which account the email is being sent. Make sure you have the sent permissions to do this. 
.EXAMPLE
    .\Check-Diskspack.ps1 -domain
    Example of how to use this cmdlet
.EXAMPLE
    .\Check-Diskspack.ps1 -domain -to user@waternet.nl -from mailaccount@waternet.nl
    Another example of how to use this cmdlet
#>

### Parameters ###  
[cmdletbinding()]
param(
    [int]
    [Alias('Threshold')]
    $minGbThreshold = 2,
    
    [string]
    $domain = 'Pab',
    
    [string]
    [Alias('to')]
    $emailadress = "topdeskpa@waternet.nl",

    [string]
    [Alias('from')]
    $fromAddress = "pa-noreply@waternet.nl"
)

### Static Variables ###
    ## SMTP Variables
        $smtpAddress = "smtp.$domain.local";

    ## Email body's
$bodytekst1 = @" 

Dit bericht is automatisch gegenereerd middels een Powershell script vanaf de SW449PPA. 

Betreft het een C schijf? 
Zet de call op naam van systeembeheer. 

Betreft het een overige schijf? 
Zet de call op naam van de groep welke in de topdesk cmdb onder aanspreekpunt staat. 

Het betreft de volgende server en disk: 

"@ 


$bodytekst2 = @" 

Dit bericht is automatisch gegenereerd middels een Powershell script vanaf de SW449PPA. 

Error message:
RPC error, RPC Service failed 

Het betreft de volgende server en disk: 

"@ 


## Get Computer object Variables ##
    $exceptlist = get-content D:\Scripts\Diskspace_check\exceptlist.txt 
    $Allcomputers = Get-ADComputer -Filter * | Sort-Object Name | Select-Object -ExpandProperty Name 
    $computers = $ALLcomputers | Where-Object {$exceptlist -notcontains $_} 


### TEST Functionality ###

    # Wanneer dit script getest moet worden kan onderstaande variablen worden gebruikt.
    # Un-commend de variable door de hash # ervoor weg te halen en vul de servernaam in.
    # Wanneer het testen klaar is moet de variable hieronder weer een hash # teken ervoor krijgen. 

#$computers = "sw441ppa"

### Start Logging
Start-Transcript -Path "$PSScriptRoot\Logs\Diskspace_check-$(get-date -f "yyyy.MM.dd-HH.mm.ss").txt" 
  
### Script Execution ###
foreach($computer in $computers) {

    If ((test-netconnection -computername $computer -port 5985).TcpTestSucceeded){  

        $disks = Get-WmiObject -ComputerName $computer -Class Win32_LogicalDisk -Filter "DriveType = 3"; 
        $computer = $computer.toupper(); 
        #$deviceID = $disk.DeviceID; 

        foreach($disk in $disks){ 

            $freeSpaceGB = [Math]::Round([float]$disk.FreeSpace / 1073741824, 2); 

            write-host $computer $disk $minGbThreshold $freeSpaceGB 

            if($freeSpaceGB -lt $minGbThreshold){ 

                $smtp = New-Object Net.Mail.SmtpClient($smtpAddress) 
                $msg = New-Object Net.Mail.MailMessage
                $msg.To.Add($emailadress) 
                $msg.From = $fromAddress 
                $msg.Subject = "Diskspace Script - Space below threshold: " + $domain + " - " + $computer + " - " + $disk.DeviceId 
                $msg.Body = $bodytekst1 + " " + $domain + " " + $computer + " - " + $disk.DeviceId + " " + $freeSpaceGB + "GB Remaining"; 
                $smtp.Send($msg) 

            }   

        } 

    } 
        
    else { 

        $smtp = New-Object Net.Mail.SmtpClient($smtpAddress) 
        $msg = New-Object Net.Mail.MailMessage 
        $msg.To.Add($emailadress)
        $msg.From = $fromAddress
        $msg.Subject = "Diskspace Script - RPC Service failed " + $domain + " - " + $computer 
        $msg.Body = $bodytekst2 + " " + $computer + " - " + $domain; 
        $smtp.Send($msg) 

    } 

} 

### End Logging
Stop-Transcript 
