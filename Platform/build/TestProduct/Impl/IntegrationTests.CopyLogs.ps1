Param
(
    [Parameter(Position=0, Mandatory=$true)]$cloneNamePattern,
    [Parameter(Position=0, Mandatory=$true)]$VmName #used to read the config with vserver address
)

<#ScriptPrologue#> Set-StrictMode -Version Latest; $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
function GetDirectoryNameOfFileAbove($markerfile) { $result = ""; $path = $MyInvocation.ScriptName; while(($path -ne "") -and ($path -ne $null) -and ($result -eq "")) { if(Test-Path $(Join-Path $path $markerfile)) {$result=$path}; $path = Split-Path $path }; if($result -eq ""){throw "Could not find marker file $markerfile in parent folders."} return $result; }
$ProductHomeDir = GetDirectoryNameOfFileAbove "Product.Root"
$ArtifactsDir = $ProductHomeDir | Join-Path -ChildPath "Artifacts"
function Get-ScriptDirectory { Split-Path $script:MyInvocation.MyCommand.Path }

function CopyLogs([string]$IpAddress, [string]$UserName, [string]$Password)
{
    Write-Host "Coping Logs from" $IpAddress ", using login:" $UserName "and password:" $Password
    # Copy Logs from VM
    LoadTypes
    $remoteEnv = New-Object JetBrains.OsTestFramework.RemoteEnvironment($IpAddress, $UserName, $Password, "$ProductHomeDir\Platform\tools\PsTools\PsExec.exe");
    Try {$remoteEnv.CopyFileFromGuestToHost(("C:\Tmp\JetLogs"), "$ArtifactsDir\JetLogs");} Catch { Write-Host $error[0]}
    Try {  $remoteEnv.CopyFileFromGuestToHost(("C:\Tmp\JetGolds"), "$ArtifactsDir\JetGolds");} Catch { Write-Host $error[0]}
}

function LoadTypes()
{
    $OsTestsFrameworkDll = "$ProductHomeDir\Platform\Lib\JetBrains.OsTestFramework.dll"
    $ZetaLongPathsDll = "$ProductHomeDir\Platform\Lib\ZetaLongPaths.dll"
 
    $Assem = ($OsTestsFrameworkDll, $ZetaLongPathsDll)
    Add-Type -Path $Assem
}

function Run
{
    $config = (& ("$ProductHomeDir\Platform\tools\OsTestFramework.Config\OsTestFramework.GetConfig.ps1") -VmName $VmName)
    & (Join-Path (Get-ScriptDirectory) "InTest\ViServer.Connect.ps1") -ViServerAddress $config.ViServerData.ViServerAddress -ViServerLogin $config.ViServerData.ViServerLogin -ViServerPasword $config.ViServerData.ViServerPasword | Out-Null
    
    $vms = @(Get-VM -Name $cloneNamePattern*)
    foreach ($vm in $vms)
    {
        if ($vm.PowerState -ne "PoweredOff")
        {
            $ips =$vm.Guest.ipaddress
            foreach ($ip in $ips){
                if ($ip.StartsWith('172.')){
                    CopyLogs $ip $config.LoginInGuestLogin $config.LoginInGuestPassword
        }}}
    }
}

Run