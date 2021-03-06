$Global:ErrorActionPreference = 'Continue'
$Script:ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Web | out-null

    $routes = &{
        new-object psobject -Property @{Name = "/"; Value = {return Launch_Application};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "ola"; Value = {return '<html><body>Hello world!</body></html>' };Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "process"; Value = {return & {(gwmi win32_process -Property * | ConvertTo-Html)}};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "go"; Value = {return Launch_Application};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "Home"; Value = {return Launch_Application};Authentication = 'basic'}
        new-object psobject -Property @{Name = "bauth"; Value = {return Launch_Application};Authentication = 'basic'}
        new-object psobject -Property @{Name = "wiauth"; Value = {return Launch_Application};Authentication = 'IntegratedWindowsAuthentication'}
        new-object psobject -Property @{Name = "time"; Value = {return (get-date|out-string)};Authentication = 'Anonymous'}
        #Put a /blank listener on each HTTPListere
        new-object psobject -Property @{Name = "blank"; Value = {return ""};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "blanki"; Value = {return ""};Authentication = 'IntegratedWindowsAuthentication'}
        new-object psobject -Property @{Name = "blankb"; Value = {return ""};Authentication = 'basic'}
        new-object psobject -Property @{Name = "data"; Value = {return (Launch_Application)};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "img"; Value = {return (get-content -Encoding byte ("$Script:ScriptFolder" + ($Global:LocPath -replace '\/','\')))};Authentication = 'Anonymous'}
        new-object psobject -Property @{Name = "css"; Value = {return (get-content ("$Script:ScriptFolder" + ($Global:LocPath -replace '\/','\')))};Authentication = 'Anonymous'}
        #"/favicon.ico" = {return FavIcon.ico}
    }

    Function ReturnFile {
        param(
            [string]$URLPath = $Global:LocPath
        )
        $LocalPath = "$Script:ScriptFolder" + ($URLPath -replace '\/','\')
        
        get-content -Encoding byte ($LocalPat)
    }

    Function Get_Theme {
        param (
            $Name,
            $Type
        )
        gci "$Script:ScriptFolder\css" "Theme_$Name_*" | ?{$_.psiscontainer} | %{
            gci $_.FULLNAME | ?{
                ($_.name -split '\.')[-1] -eq $Type
            } | %{
                $File = $_
                switch ($Type)
                {
                    'js' {
                        Write_Tag -Tag Script -TagData "FC='$($_.Name)'" -Content (GC -LiteralPath $File.FULLNAME)
                        if ($Type -eq 'js') 
                        {
                            gci "$Script:ScriptFolder\js" *.js -Recurse | ?{-not $_.psiscontainer} | %{
                                Write_Tag -Tag Script -TagData "FC='$($_.Name)'" -Content (GC -LiteralPath $File.FULLNAME)
                            }
                        }
                    }
                    'css' {Write_Tag -Tag Script -TagData "FC='$($_.Name)'" -Content (GC -LiteralPath $File.FULLNAME)}
                    'HTMLMenu' {
                        & "$Script:ScriptFolder\Start-WebAppServer_SDN_Client\Apps\ControlPannel.ps1" -AppArguments (new-object psobject -Property @{
                            Name="Command";
                            Value='ControlPannel'
                        })
                    }
                    default {GC $_.FULLNAME }
                }
            }
        }
    }

    Function Update_Theme {
        param (
            $Name
        )
        [array]$Global:Include_Java = Get_Theme -Name $Name -Type js
        [array]$Global:Include_CSS = Get_Theme -Name $Name -Type css
        [array]$Global:Include_HTML_Menu = Get_Theme -Name $Name -Type HTMLMenu 
        [array]$Global:Include_HTML_Header = Get_Theme -Name $Name -Type HTMLHeader
        [array]$Global:Include_HTML_Footer = Get_Theme -Name $Name -Type HTMLFooter
        [array]$Global:Include_HTML_Navigation = Get_Theme -Name $Name -Type HTMLNavigation
    }

    Function LastCall {
        if ($Global:IEWindow.Application)
        {
            $Global:IEWindow.Quit()
            $Global:IEWindow = $Null
        }
        if ($global:listener)
        {
            $context = $global:listener.GetContext()
            $requestUrl = $context.Request.Url
            $response = $context.Response
            $response.StatusCode = 404
            $response.Close()
            $Global:Listener.Prefixes | %{$_} | ?{$_} | %{$Listener.Prefixes.Remove($_)} 2>$null
            $Global:Listener.stop()
            $Global:Listener.Close()
            $Global:Listener.Dispose()
        }
        Remove-Variable listener                   -Scope global -ErrorAction silent -Force
        Remove-Variable listener_Anonymous         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_BasicAuth         -Scope global -ErrorAction silent -Force
        Remove-Variable listener_WindowsIntegrated -Scope global -ErrorAction silent -Force
    }
    
    Function GetRandomUnusedTCPPort ([int]$Low = 982,[int]$High=984){
    #Get a random TCP Port that is not used or within a narrow grouping.
    $Netstat = netstat -n -a
    $High++
    $low--
    $LocalPorts = &{$low;$Netstat | %{[int]($_ -split '\s\s*' -match ":" -split ":")[1]}; $High } |sort -Unique |?{($_ -le ($High)) -and ($_ -ge ($Low))}
    $LargestopenPortRange = $LocalPorts | %{
        $A = $_
        if ($B) {new-object psobject -Property @{Start=($B+1);Stop=($A-1);Gap=($A-1-$B)}}
        $B = $A
    } | sort gap -Descending | select -First 1
    $A=0;$B=0
    $LargestopenPortRange | %{
        if ($_.Start -eq $_.Stop)
        {
            $_.Start
        }
        ELSEif ($_.Start -lt $_.Stop)
        {
            get-random -Minimum $_.Start -Maximum $_.stop
        }
        ELSE
        {
            return (Write-Error -message "No ports available in range")
        }
    }
}

    function GetIEWindow {
        <#
        .Synopsis
            Returns existing Internet Explorer windows.
        #>
        param (
            $URLMatches,
            $URLLike
        )
        $app = new-object -com shell.application
        if ([bool]$URLMatches)
        {
            $app.windows() | where {$_.Type  -eq "HTML Document" -and $_.LocationURL -match $URLMatches} 
        }
        ELSEIF ([bool]$URLLike)
        {
            $app.windows() | where {$_.Type  -eq "HTML Document" -and $_.LocationURL -Like $URLLike} 
        }
        ELSE
        {
            $app.windows() | where {$_.Type  -eq "HTML Document"}
        }
    }
    
    Function Write_FavIcon.ico {
        param (
            $IconFile = (gci "$Script:ScriptFolder\IMG" "favicon*.ico" | sort length -Descending | select -First 1 | %{$_.fullname})
        )
        $ImageFormat = ($IconFile -split '\.')[-1]
        Get-Content $IconFile -TagData "rel='shortcut icon'"
    }
    
    Function Write_Img_Base64Encoded {
        param (
            $Tag = "IMG",
            $TagData,
            $ImageFormat = "bmp",
            $File,
            $Bytes
        )
        if ($File)
        {
            $BitmapBase64 = [convert]::ToBase64String((get-content -Path $File -Encoding byte))
        }
        ELSE
        {
            $BitmapBase64 = [convert]::ToBase64String($Bytes)
        }
        return ("<$Tag $TagData src='data:image/$ImageFormat;base64,"+$BitmapBase64+"' alt='Embeded Image'/>")
    }

    function Indent {
        param (
            [int]$Indent,
            [string[]]$Text
        )
        begin {
            if ($Text)
            {
                $Text -split "`n" | %{"`n" + ((0..($Indent))|%{"`t"})+$_}
            }
        }
        process {
            $_ -split "`n" | ?{$_} | %{"`n" + ((0..($Indent))|%{"`t"})+$_} 
        }
        end {}
    }
    
    function StopTable {
        if ($script:InTable)
        {
            if ($script:TableData)
            {
                $script:TableData
                Remove-Variable TableData -Scope Script
            }
            
            "</TBODY></TABLE>"
            $Script:TableInclude_Old = $Null
            $script:InTable = $False
        }
    }

    function StartTable {
        param (
            [string]$TagData = "border=1 style=""font-size:12px;background-color:white;color:black;""",
            [array]$TableInclude
        )
        if ($Script:TableInclude_Old -and ("$TableInclude" -ne "$Script:TableInclude_Old"))
        {
            StopTable
        }
        $script:TableData = New-Object system.collections.arraylist
        if ($TagData -notmatch '^Name=|\sName=') 
        {
            [string]$TableName = "DataSet_$($TableInclude -join ",")"
            $TagData = 'Name='+$TableName+' '+$TagData
        }
        if (-not $Script:InTable) {
            $script:InTable = $True
            '<Table '+$TagData+'>'+"`n"+'<THEAD><TR>'+(($TableInclude |?{$_}| %{'<TH>'+$_+'</TH>'}) -join "") + '</TR></THEAD>'+"`n<TBODY>"
        }
        $Script:TableInclude_Old = $TableInclude
    }
    
    function Write_Tag {
        param (
            $Tag,
            $TagData,
            $Content,
            [int]$Indent = 1
        )
        begin {
            $O = '<'+$Tag+' '+$TagData+'>' + (($content -split "`n" | ?{$_}) -join "`n")
        }
        Process {
            $O = $O + (($_ -split "`n" ) -join "`n")
        }
        End {
            $O = $O + '</'+$Tag+'>'
            $O
        }
    }

    function Write_Table {
        param (
            $Inputobject,
            [string]$TagData = "border=1 style=""font-size:12px;background-color:white;color:black;""",
            [array]$TableInclude
        )
        begin {
            [array]$Data = $Inputobject
        }
        process {
            $_ | ?{$_} | %{
                [array]$Data = $Data + $_
            }
        }
        End {
            if (-not $TableInclude)
            {
                $TableInclude = Get-Member -InputObject $Data[0] -MemberType properties | %{$_.name}
            }
            StartTable -TagData $TagData -TableInclude $TableInclude
            $Data | ?{$_} | %{
                $O = $_; 
                Write_Tag -Tag "TR" -Content ($TableInclude | %{
                    Write_Tag -Tag "Td" -Content ($O.($_))}) | %{$script:TableData.add($_)
                } | out-null
            }
            StopTable
        }
    }
    
    Function GzipResponse {
        param ($Buffer)
        $MS  = New-Object system.io.MemoryStream 
        $Zip = New-Object System.IO.Compression.GZipStream  $ms, ([IO.Compression.CompressionMode]::Compress), $true
        $zip.Write($buffer, 0, $buffer.Length);
        $zip.Close()
        $ms.ToArray();
        $ms.Close()
        $Script:response.AddHeader("Content-Encoding", "gzip");
    }
    
    function Write_Script {
        param ($TagData,$Content)
        '<Script '+$TagData+'>'+"`n"
        $Content+"`n"
        '</Script>'
    }

    function Write_Style {
        param ($TagData,$Content)
        '<Style '+$TagData+'>'+"`n"
        indent -Indent 1 -Text $Content
        '</Style>'
    }
    
    function Write_Head {
        Write_Tag -Tag 'Head' -Content ( &{
            gci "$Script:ScriptFolder\CSS" '*.css' | %{
                $F = $_
                (gc $_.fullname) -join "`n"
            } | %{Write_Style -TagData "comment='From: $($F.name)'" -Content $_}
            gci "$Script:ScriptFolder\CSS" '*.cssStub' | %{
                $F = $_
                $CSSElementName = $_.name -replace '\.cssStub$'
                $CSSElementName + '{' + (gc $_.fullname) + '}' +"`n"
                #indent -Indent 1 -Text ($CSSElementName + '{' + (gc $_.fullname) + '}' + "`n`n")
            } | %{Write_Style -TagData "comment='From: $($F.name)'" -Content $_}
            $Global:Include_CSS |  %{ Write_Style -TagData "comment='Theme Style Data'" -Content $_}
            $Global:Include_Java | %{ Write_Script -TagData "type='text/javascript' comment='Theme Style Data'" -Content $_ }
        })
    }
    
    function Write_Body {
        param (
            $TagData = ("STYLE=""font:12 pt arial; color:white;background-color:#333333;"" onload=""main"""),
            $Content,
            [int]$indent = 1
        )
        indent -Indent $Indent -Text ('<BODY '+$TagData+'>')
        Write_Tag -Tag div -TagData "style='float:left'" -Content (
            Write_Tag -Tag nav -TagData "class='menu'" -content (. "$Script:ScriptFolder\Apps\Menu.ps1")
        )
        write_tag -tag div -TagData "style='float:right'" -Content (&{
            Write_Tag -Tag header -TagData "class='header'" -content (&{
                $Global:Include_HTML_Header
                Write_Tag -Tag SPAN -TagData "class='Navigation'" -content $Global:Include_HTML_Navigation
            })
            Write_Tag -Tag article -TagData "class='MainBody'" -content $Content
            Write_Tag -Tag footer -TagData "class='footer'" -content $Global:Include_HTML_Footer
        })
        indent -Indent $Indent -Text '</BODY>'
    }
    
    function Get-GoogleCSEQueryString {
        #http://www.powershelladmin.com/wiki/Accessing_the_Google_Custom_Search_API_using_PowerShell#Requirements
        param([string[]] $Query)
        #Add-Type -AssemblyName System.Web # To get UrlEncode()
        $QueryString = ($Query | %{ [Web.HttpUtility]::UrlEncode($_)}) -join '+'
        # Return the query string
        $QueryString
    }
    
    Function Search_GoogleAPIsCustomSearch {
        param (
            $SearchString = 'inurl:"/events/"'
        )
        $QueryString = Get-GoogleCSEQueryString $SearchString
        $Uri = "https://www.googleapis.com/customsearch/v1?key=$GoogleCSEAPIKey&cx=$GoogleCSEIdentifier&q=$QueryString"
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$false
        $WC.Headers.Add("user-agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)")
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $wc.DownloadString($Uri)
    }

    Function Search_Google {
        param (
            $SearchString = 'inurl:"/events/"'
        )
        $QueryString = Get-GoogleCSEQueryString $SearchString
        $Uri = "https://www.google.com/#q=$QueryString"
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$false
        $WC.Headers.Add("user-agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)")
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $wc.DownloadString($Uri)
    }
   
    function Write_HTML {
        param ($TagData,$Content)
        '<HTML '+$TagData+'>'
        ''
        Write_Head
        ''
        write_body -Content $content
        ''
        '</HTML>'
    }
    
    function Launch_Application {
        param (
            $User = $script:context.user,
            $Query = $script:requestUrl.Query,
            $ApprovedNames = ("Navigate","Help","Launch","Eleveted","look","App")
        )
        if ($Global:ReaderString)
        {
            $Arguments = $Global:ReaderString | ?{$_}| %{$S = $_ -split "=(.*)" |%{[Web.HttpUtility]::UrlDecode($_)};$Name = $S[0];$Value = $S[1];new-object psobject -Property @{Name=$Name;Value=$Value} }
        }
        ELSE
        {
            $Arguments = $requestUrl.Query -replace '\%22','"' -split "\?"| ?{$_} | %{$S = $_ -split "=(.*)";$Name = $S[0];$Value = $S[1];new-object psobject -Property @{Name=$Name;Value=$Value} }
        }
        $RequestedApp = $Arguments | ?{$_.name -eq "App"} | select -First 1
        if (-not $RequestedApp) {$RequestedApp = @{Name="App";Value="ControlPannel"}}
        $App = $script:Apps | ?{$_.name -eq ($RequestedApp.value + ".ps1")} | select -First 1
        #$App = $script:Apps | ?{$A = $_;$RequestedApp.value -split ',' | ?{$R = $_;$A.name -eq ($R + ".ps1")}} #| select -First 1
        if ($App)
        {
            $ApprovedArgs = & $App.fullname -GetApprovedArgs
            $AppArguments = $Arguments | ?{$A = $_.name;$ApprovedArgs | ?{$_ -eq $A}}
            return (. $App.fullname -AppArguments $AppArguments)
        }
    }

    Function AsHTML {
        param(
            [array]$InputObject
        )
        begin {
            function ProcessInputObject {
                param ($InputObject)
                if (($InputObject.gettype().name -eq "string") -and ($InputObject[0] -eq "<"))
                {
                    $InputObject
                }
                ELSE
                {
                    IF ([bool]$SCRIPT:HTable_Data)
                    {
                        if ($InputObject.HTMLOutputFormat -ne "HTABLE")
                        {
                            Write_HTable -Inputobject $SCRIPT:HTable_Data
                            $SCRIPT:HTable_Data = new-object system.collections.arraylist
                        }
                    }
                    ELSE
                    {
                        $SCRIPT:HTable_Data = new-object system.collections.arraylist
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "HTABLE")
                    {
                        $SCRIPT:HTable_Data.add(($InputObject | select -ExcludeProperty HTMLOutputFormat))|Out-Null
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "Tag")
                    {
                        write_tag -Tag $InputObject.tag -TagData $InputObject.TagData -Content $InputObject.Content
                    }
                    ELSE
                    {
                        switch ($InputObject.gettype().name)
                        {
                            "string" {
                                stoptable
                                '<P data_type="String">' + $InputObject + '</P>'
                            }
                            default {
                                $Properties = Get-Member -InputObject $InputObject -MemberType properties | %{$_.name}
                                if ($BuildHeaders)
                                {
                                    $Headers = $Properties 
                                }
                                IF (-not $SCRIPT:InTable -or ("$Properties" -ne "$Script:TableInclude_Old")) 
                                {
                                    starttable -TableInclude $Properties | %{$script:TableData.add($_)} | out-null
                                }
                                Write_Tag -Tag "TR" -Content (
                                    $Properties | %{
                                            Write_Tag -Tag "Td" -Content ($InputObject.($_))
                                        }
                                ) | %{$script:TableData.add($_)} | out-null
                            }
                        }
                    }
                }
            }
            $InputObject | ?{$_} | %{
                ProcessInputObject -InputObject $_
            }
        }
        process {
            if ($_)
            {
                ProcessInputObject -InputObject $_
            }
        }
        end {
            StopTable
        }
    }
    
    Function Write_HTable {
        Param (
            [array]$Inputobject,
            [array]$Property,
            $RowTitleProperty
        )
        begin {
            [array]$Data = $Inputobject | ?{$_}
        }
        process{
            $_ | ?{$_} | %{$Data = $Data + $_}
        }
        end {
            if ($Data)
            {
                if ($Property) 
                {
                    $Headers = $Property
                }
                ELSE
                {
                    $Property = $Data | select -First 5 | %{Get-Member -InputObject $_ -MemberType Property | %{$_.name} | ?{$_ -ne 'HTMLOutputFormat'}}
                    $PropertyNew = $Property | ?{$_} | %{
                        $P = $_;
                        $P;
                        $Property = $Property | ?{$_ -ne $P}
                    }
                    $Property = $PropertyNew
                    $Headers = (1..($Data.count))|%{"Value$_"}
                }
                $KeyProperty = $Null
                if ($RowTitleProperty)
                {
                    $KeyProperty = $RowTitleProperty
                    $Headers = $Data | %{$_.($KeyProperty)}
                }
                ELSE
                {
                    "pscomputername","computername","__Server","Date","time" | ?{($Data | select -skip 0 -First 1).pscomputername} | select -First 1| %{
                        $KeyProperty = $_
                        $Headers = $Data | %{$_.($KeyProperty)}
                    }
                }
                [array]$TableInclude = 'Property'
                $TableInclude = $TableInclude + $Headers | ?{$_}
                $Property | %{
                    $PropertyItem = $_
                    $I = 0
                    $Record = New-Object psobject -Property @{Property=$PropertyItem}
                    $Headers | ?{$_} | %{
                        $HeaderItem = $_
                        #$DataItem = $Data[$I]
                        Add-Member -InputObject $Record -MemberType noteproperty -name $HeaderItem -Value ((($Data | select -skip $i -First 1).($PropertyItem) | out-string) -replace '^\s\s*|\s\s*$')
                        $I++
                    }
                    $Record | select -Property $TableInclude
                } |Write_Table -TableInclude $TableInclude
                
            }
        }
    }
    
    Function PeriodicRequest {
        Param (
            [int]$Interval = 5,
            [string]$url
        )
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$true

        while ($True)
        {
            
            ($URL + $Args)|?{$_ -match "https*:\/\/"}  | %{
                $wc.DownloadString("$_")|out-null
            }
            Sleep $Interval
        }
    }
    
    function IsLocalRequest {
        $Query = $script:requestUrl
    }

    Function UpdateUserContext {
        if ($global:context.User.Identity.Name -match "\\")
        {
            $global:UserName = $global:context.User.Identity.Name -split "\\" | select -Last 1
            $global:Domain = $global:context.User.Identity.Name -split "\\" | select -First 1
        }
        ELSEIF ($global:context.User.Identity.Name -match "@")
        {
            $global:Domain = $global:context.User.Identity.Name -split "@" | select -Last 1
            $global:UserName = $global:context.User.Identity.Name -split "@" | select -First 1
        }
    }

    Function AsHTML {
        param(
            [array]$InputObject
        )
        begin {
            function ProcessInputObject {
                param ($InputObject)
                if (($InputObject.gettype().name -eq "string") -and ($InputObject[0] -eq "<"))
                {
                    $InputObject
                }
                ELSE
                {
                    IF ([bool]$SCRIPT:HTable_Data -and ($InputObject.HTMLOutputFormat -ne "HTABLE"))
                    {
                        Write_HTable -Inputobject $SCRIPT:HTable_Data
                        $SCRIPT:HTable_Data = new-object system.collections.arraylist
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "HTABLE")
                    {
                        $SCRIPT:HTable_Data.add(($InputObject | select -ExcludeProperty HTMLOutputFormat))|Out-Null
                    }
                    IF ($InputObject.HTMLOutputFormat -eq "Tag")
                    {
                        write_tag -Tag $InputObject.tag -TagData $InputObject.TagData -Content $InputObject.Content
                    }
                    ELSE
                    {
                        switch ($InputObject.gettype().name)
                        {
                            "string" {
                                stoptable
                                '<P data_type="String">' + $InputObject + '</P>'
                            }
                            default {
                                $Properties = Get-Member -InputObject $InputObject -MemberType properties | %{$_.name}
                                if ($BuildHeaders)
                                {
                                    $Headers = $Properties 
                                }
                                IF (-not $SCRIPT:InTable -or ("$Properties" -ne "$Script:TableInclude_Old")) 
                                {
                                    if ($script:TableData.count -eq $null)
                                    {
                                        $script:TableData = New-Object system.collections.arraylist
                                    }
                                    starttable -TableInclude $Properties | %{$script:TableData.add($_)} | out-null
                                }
                                Write_Tag -Tag "TR" -Content (
                                    $Properties | %{
                                            Write_Tag -Tag "Td" -Content ($InputObject.($_))
                                        }
                                ) | %{$script:TableData.add($_)} | out-null
                            }
                        }
                    }
                }
            }
            $InputObject | ?{$_} | %{
                ProcessInputObject -InputObject $_
            }
        }
        process {
            if ($_)
            {
                ProcessInputObject -InputObject $_
            }
        }
        end {
            StopTable
        }
    }
    
    Function PeriodicRequest {
        Param (
            [int]$Interval = 5,
            [string]$url
        )
        $wc=new-object system.net.webclient
        $wc.UseDefaultCredentials=$true

        while ($True)
        {
            
            ($URL + $Args)|?{$_ -match "https*:\/\/"}  | %{
                $wc.DownloadString("$_")|out-null
            }
            Sleep $Interval
        }
    }
    
    function IsLocalRequest {
        $Query = $script:requestUrl
    }

    Function UpdateUserContext {
        if ($global:context.User.Identity.Name -match "\\")
        {
            $global:UserName = $global:context.User.Identity.Name -split "\\" | select -Last 1
            $global:Domain = $global:context.User.Identity.Name -split "\\" | select -First 1
        }
        ELSEIF ($global:context.User.Identity.Name -match "@")
        {
            $global:Domain = $global:context.User.Identity.Name -split "@" | select -Last 1
            $global:UserName = $global:context.User.Identity.Name -split "@" | select -First 1
        }
    }


    Function GetGroupMembership {
        Param (
            [string]$Name,
            [System.Collections.ArrayList]$GroupMembership = (New-Object System.Collections.ArrayList),
            $Searchon = 'samaccountname'
        )
        ([ADSISEARCHER]"$Searchon=$($Name)").Findone() | ?{$_.Properties} | %{$_.Properties.memberof} | ?{-not $GroupMembership.Contains([string]$_)} | %{
            $GroupMembership.add($_) | out-null
            GetGroupMembership -Name $_ -GroupMembership $GroupMembership -Searchon 'dn' | ?{-not $GroupMembership.Contains([string]$_)} | %{
                $GroupMembership.add($_) | out-null
            }
        }
        $GroupMembership
    } 

    $AppsFolder = "$Script:ScriptFolder\Apps"
    if (-not (test-path $AppsFolder)) {md $AppsFolder}
    $Apps = gci $AppsFolder *.ps1

    Function IsUserMemberOf {
        param(
            $UserName = $global:context.User.Identity.Name,
            [string[]]$GroupCN,
            $Searchon
        )
        if ($UserName -match "@") 
        {
            if (-not $Searchon) {$Searchon = 'userprincipalname'}
        }
        ELSEif ($UserName -match "\\") 
        {
            $UserName = $UserName -split '\\' | select -First 1 -Skip 1
            if (-not $Searchon) {$Searchon = 'samaccountname'}
        }
        ELSE 
        {
            if (-not $Searchon) {$Searchon = 'samaccountname'}
        }
        GetGroupMembership -Name $UserName -Searchon $Searchon |?{$_} | ?{$DN = $_;$N = $_ -replace '^CN=([^,]+).+$','$1'; $GroupCN| ?{($_ -eq $N) -or ($_ -eq $DN)}}
    }

    Function IsolateduserSession {
        param (
            [string]$User,
            [string]$Purpose = 'Sensitive'
        )
        $Pssession = Get-PSSession -Name "$($user)_$($Purpose)" -ErrorAction SilentlyContinue
        if ($global:context.User.Identity.Password -and -not $Pssession)
        {
            $Cred = new-object -typename System.Management.Automation.PSCredential `
                -argumentlist $username, ($global:context.User.Identity.Password | ConvertTo-SecureString -AsPlainText -Force)
            New-PSSession -Name "$($user)_$($Purpose)" -Credential $Cred -ErrorAction Continue
        }
    }