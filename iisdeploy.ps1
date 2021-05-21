$websiteURL = Read-Host -Prompt 'Input your server  IP'
$ServerName = Read-Host -Prompt 'Input your server name'
$mashinName = $ServerName
$physicalPath = "C:\sites\dev-testsite"
$ip = [ipaddress]$ServerName
$iisWebsiteName = "Test-iis-instance-b"

$Sessions = New-PSSession -credential $ServerName\Administrator -computername  $ip

Invoke-Command -Session $Sessions -ScriptBlock { Get-WindowsOptionalFeature -Online -FeatureName IIS-ManagementScriptingTools }

Invoke-Command -Session $Sessions -ScriptBlock {
    if ((Get-WindowsFeature Web-Server).InstallState -ne "Installed") {
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
    }
    else {
    }
}

Invoke-Command -Session $Sessions -ScriptBlock {
    if (Test-Path IIS:\AppPools\:iisWebsiteName) {
        Remove-WebAppPool -Name :iisWebsiteName
    }
}

Invoke-Command -Session $Sessions -ScriptBlock { New-WebAppPool -Name :iisWebsiteName }

Invoke-Command -Session $Sessions -ScriptBlock {
    if (!(Get-Website -Name :iisWebsiteName)) {

        New-WebSite -Name :iisWebsiteName -Port 80 -IPAddress * -HostHeader :websiteUrl -PhysicalPath :physicalPath -ApplicationPool :iisWebsiteName
        Set-ItemProperty "IIS:\Sites\:iisWebsiteName" -Name  Bindings -value @{protocol = "http"; bindingInformation = "*:80::websiteUrl" }
    }
}

#The code didn't work correctly. I get an error "Invalid application pool name"