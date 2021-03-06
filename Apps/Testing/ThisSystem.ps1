$Win32_ComputerSystemSelect = @"
AdminPasswordStatus
AutomaticManagedPagefile
AutomaticResetBootOption
AutomaticResetCapability
BootOptionOnLimit
BootOptionOnWatchDog
BootROMSupported
BootupState
Caption
ChassisBootupState
CreationClassName
CurrentTimeZone
DaylightInEffect
Description
DNSHostName
Domain
DomainRole
EnableDaylightSavingsTime
FrontPanelResetStatus
InfraredSupported
InitialLoadInfo
InstallDate
KeyboardPasswordStatus
LastLoadInfo
Manufacturer
Model
Name
NameFormat
NetworkServerModeEnabled
NumberOfLogicalProcessors
NumberOfProcessors
OEMStringArray
PartOfDomain
PauseAfterReset
PCSystemType
PowerManagementCapabilities
PowerManagementSupported
PowerOnPasswordStatus
PowerState
PowerSupplyState
PrimaryOwnerContact
PrimaryOwnerName
ResetCapability
ResetCount
ResetLimit
Roles
Status
SupportContactDescription
SystemStartupDelay
SystemStartupOptions
SystemStartupSetting
SystemType
ThermalState
TotalPhysicalMemory
UserName
WakeUpType
Workgroup
"@ -split "`n" -replace "\s"

"You are using:"
#$Win32_ComputerSystemSelect | %{New-Object psobject -property @{Name=$_;Value=($Global:Win32_ComputerSystem.($_))}}|select Name,Value

$Global:Win32_ComputerSystem | Write_HTable -Property $Win32_ComputerSystemSelect 
"<BR>"
"Drive Space"
Get-WmiObject win32_volume | ?{$_.Capacity}  | Write_HTable -Property DriveType,FileSystem,DriveLetter,Capacity,FreeSpace -RowTitleProperty DriveLetter
#"<BR>"
#Get-WmiObject win32_volume -property * | write_htable -RowTitleProperty DriveLetter