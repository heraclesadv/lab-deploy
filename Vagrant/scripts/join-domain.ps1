#This file is hosted on master, modify the hosted version when u modify it
# Purpose: Joins a Windows host to the windomain.local domain which was created with "create-domain.ps1".
param ([String] $newDNSServers)

$hostsFile = "c:\Windows\System32\drivers\etc\hosts"

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Joining the domain..."

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) First, set DNS to DC to join the domain..."
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPAddress -match $newDNSServers.Substring(0,$newDNSServers.Length-1)}
$adapters | ForEach-Object {if (!($_.Description).Contains("Hyper-V")) {$_.SetDNSServerSearchOrder($newDNSServers); $_.SetWINSServer($newDNSServers, "")}}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Now join the domain..."
$hostname = $(hostname)
$user = "windomain.local\vagrant"
$pass = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$DomainCred = New-Object System.Management.Automation.PSCredential $user, $pass

Add-Computer -DomainName "windomain.local" -credential $DomainCred -OUPath "ou=Workstations,dc=windomain,dc=local"

