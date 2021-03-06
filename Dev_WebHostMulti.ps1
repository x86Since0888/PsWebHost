param (
    $url = 'http://ws.skarke.net:80/',#'https://ws.skarke.net:443/'),
    $routes,
    [switch]$StopListener,
    #[string]$AuthenticationSchemes = "Anonymous",
    #[string]$AuthenticationSchemes = "Basic",
    #[string]$AuthenticationSchemes = "IntegratedWindowsAuthentication",
    [string]$DefaultServiceNames,
    [switch]$NoIE
)

begin {
    $script:ScriptPath = $MyInvocation.MyCommand.Definition
    $script:ScriptFolder = SPLIT-PATH $MyInvocation.MyCommand.Definition
    $Script:ScriptName = (split-path -Leaf $script:ScriptPath) -replace '\.ps1$'
    $AppsFolder = "$Script:ScriptFolder\Apps"
    if (-not (test-path $AppsFolder)) {md $AppsFolder}
    $Apps = gci $AppsFolder *.ps1
    

    . "$script:ScriptFolder\Functions\Function_Core.ps1"

    LastCall
    
    $SCRIPT:HTable_Data = new-object system.collections.arraylist

    if (-not $Global:ThemeName) {$Global:ThemeName = 'Blue1'}
    Update_Theme -Name $Global:ThemeName 
    $ErrorActionPreference = "Continue"
    $Global:Win32_ComputerSystem = Get-WmiObject win32_computersystem 
    $Global:URL = $URL
    
    $F = 'C:\Program Files\Internet Explorer\iexplore.exe'
    if (Test-Path $F) {$IE = $F}
    $F = 'C:\Program Files (x86)\Internet Explorer\iexplore.exe'
    if (Test-Path $F) {$IE = $F}

    #$global:listenerXML = ($ScriptPath -replace '\.ps1$','_listener.cli.xml')
    if (-not [bool]$global:listener_Anonymous)
    {
        $global:listener_Anonymous = New-Object System.Net.HttpListener
        $global:listener_Anonymous.AuthenticationSchemes = 'anonymous'
    }
    if (-not [bool]$global:listener_BasicAuth)
    {
        $global:listener_BasicAuth = New-Object System.Net.HttpListener
        $global:listener_BasicAuth.AuthenticationSchemes = 'basic'
    }
    if (-not [bool]$global:listener_WindowsIntegrated)
    {
        $global:listener_WindowsIntegrated = New-Object System.Net.HttpListener
        $global:listener_WindowsIntegrated.AuthenticationSchemes = 'IntegratedWindowsAuthentication'
    }
    [System.Net.HttpListener[]]$Global:ListenerObjects = $global:listener_Anonymous,$global:listener_BasicAuth,$global:listener_WindowsIntegrated
    #if($AuthenticationSchemes)
    #{
    #    $global:listener.AuthenticationSchemes = $AuthenticationSchemes
    #}
    if($DefaultServiceNames)
    {
        $Global:ListenerObjects|?{$_}|%{$_.DefaultServiceNames = $DefaultServiceNames}
    }
    $Global:URL | ?{$_} | %{
        $U = $_
        $routes | ?{$_} | %{
            $R = $_
            [string]$N = $R.Name
            if ($n.Length -eq 0)
            {
                [string]$N = '/'
            }
            ELSE
            {
                $N = '/' + $R.Name + '/'
            }
            switch ($R.Authentication) {
                'Anonymous' {
                    $global:listener_Anonymous.Prefixes.Add(([string]$U + $N))
                }
                'basic' {
                    $global:listener_BasicAuth.Prefixes.Add(([string]$U + $N))
                }
                'IntegratedWindowsAuthentication' {
                    $global:listener_WindowsIntegrated.Prefixes.Add(([string]$U + $N))
                }
            }
        }
    }
    #$global:listener.Prefixes.Add(('http://localhost:' + $HttpPort + '/'))

    $Global:ListenerObjects|?{$_}|%{$_.Start()}
    #$global:listener | Export-Clixml -Path $global:listenerXML

    Write-Host "Listening at $Global:URL..."


    if (get-job -Name PeriodicRequest -ea silentlycontinue)
    {
        Stop-Job -Name PeriodicRequest
        Remove-Job -Name PeriodicRequest
    }
    #Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(5,('http://localhost:' + $HttpPort + '/blank')))
    $Global:ListenerObjects|?{$_}|%{
        $Prefix = $_.Prefixes|?{
            $_ -match '\/blank.(\/|)$'}|select -First 1;
            Start-Job -Name PeriodicRequest -ScriptBlock ([scriptblock]::Create((Get-Command -Name PeriodicRequest).definition)) -ArgumentList (@(5,(($Prefix| %{$_ -replace '\*','localhost'}))))
    }
    
    if (-not $NoIE)
    {
        $Global:IEWindow = GetIEWindow -URLLike "$Global:URL*"
        if (-not $Global:IEWindow)
        {
            & $IE (($Global:URL | select -First 1) -replace '\*','localhost')
            $I = 0
            While (-not $Global:IEWindow -and ($I -lt 10))
            {
                $Global:IEWindow = GetIEWindow -URLLike "$Global:URL*"
                $I++
            }
        }
    }
    $I = 0
    while ($Global:ListenerObjects | ?{$_.IsListening})#$global:listener.IsListening)
    {
        $Global:ListenerObjects | ?{$_.IsListening} | %{
            $global:listener = $_
            if (-not $NoIE)
            {
                $I++
                $Global:IEWindow = GetIEWindow -URLLike "$Global:URL*"
                if (-not $Global:IEWindow)
                {
                    if ($I -gt 2) {return LastCall}
                }
            }
            $global:context = $global:listener.GetContext()
            $requestUrl = $global:context.Request.Url
            $response = $global:context.Response
            $global:WebRequest = $global:context.Request
            if ($global:WebRequest.HttpMethod -eq 'post')
            {
                $Global:Reader = new-object System.IO.StreamReader $global:WebRequest.InputStream,$global:WebRequest.ContentEncoding
                $Global:ReaderString = $Global:Reader.ReadToEnd() -split '\&'
                $Global:PostText = $Global:ReaderString|?{$_}|%{[system.web.httputility]::UrlDecode($_)}
            }
            ELSE
            {
                $Global:ReaderString = $null
                $Global:PostText = $null
            }


            Write-Host ''
            Write-Host "> $requestUrl"
         
            $localPath = $requestUrl.LocalPath
            #$route = $routes.Get_Item($requestUrl.LocalPath)
            $Global:LocPath = ($requestUrl.LocalPath -replace '\/$|\\$')
        
            $Global:LocPathSplit = ($Global:LocPath -split '\?')[0] -split '\/|\\'
            $Global:RootRoute = $Global:LocPathSplit[1]
            $Global:LocPath = $Global:LocPathSplit -join '/'
            if (-not $Global:RootRoute) {$Global:RootRoute = 'Home'}
            $route = $routes.GetEnumerator() | ?{$_.name -eq $Global:RootRoute} | select -First 1
        

            if ($route.name -match '^(img)$')
            {
                [byte[]]$buffer = & $route.value
                $response.ContentType = 'Image/' + ([string]([array]($Global:LocPathSplit[-1] -split "\."))[-1]).ToUpper()
                $response.ContentType
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            ELSEif ($route -eq $null)
            {
                $response.StatusCode = 404
            }
            else
            {
                if ($route.name -match '^(data|time|css|blank)$')
                {
                    $content = & $route.value
                }
                ELSE
                {
                    $content = & $route.value | AsHTML
                    $content = Write_HTML -Content $content
                }
            
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentLength64 = $buffer.Length
                if ($Buffer.Length -gt 1000)
                {
                    [byte[]]$GZipData = GzipResponse -Buffer $Buffer
                    $response.OutputStream.Write($GZipData, 0, $GZipData.Length)
                }
                ELSE
                {
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            $response.OutputStream.position
            $response.OutputStream.Close()
            $response.Close()
            $responseStatus = $response.StatusCode
            Write-Host "< $responseStatus"
            if ($I -gt 30000000) {return LastCall}
        }
    }
}

process {
}

End {
    LastCall 2> $null
    Stop-Job -Name PeriodicRequest*
    Remove-Job -Name PeriodicRequest*
}
