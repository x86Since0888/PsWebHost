$ComputerName | ForEach-Object { 
$Computer = $_ 
$Namespace = "root\WMI"  
$ComputerSystemProduct = (Get-WmiObject -class Win32_ComputerSystemProduct -computername $Computer -namespace $namespace -ea "silentlycontinue")
$IdentifyingNumber  = $ComputerSystemProduct.IdentifyingNumber  
Get-WmiObject -class MSFC_FCAdapterHBAAttributes -computername $Computer -namespace $namespace -ea "silentlycontinue" | 
ForEach-Object { 
$NodeWWN         = (($_.NodeWWN) | ForEach-Object {"{0:x}" -f $_} | %{
  [string]$hex = $_
  if ($hex.length -eq 1) {"0" + $hex}
  if ($hex.length -eq 2) {$hex} 
}) -join ":" 
#$NodeWWN           = :$NodeWWN:
#$NodeWWN           = $NodeWWN.replace(":0:",":00:")
#$NodeWWN           = (1..$($nodewwn.length - 2))|%{$nodewwn[$_]}
$hash=@{ 
ComputerName        = $_.__SERVER 
IdentifyingNumber   = $IdentifyingNumber
NodeWWN             = $NodeWWN
Active              = $_.Active 
DriverName          = $_.DriverName 
DriverVersion       = $_.DriverVersion 
FirmwareVersion     = $_.FirmwareVersion 
Model               = $_.Model 
ModelDescription    = $_.ModelDescription 
} 
New-Object psobject -Property $hash 
}#Foreach-Object(Adapter) 
}#Foreach-Object(Computer) 
