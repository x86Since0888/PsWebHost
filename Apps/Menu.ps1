$UserProfile = Get_Profile
"<ul class='menu' style='float:left'>"
(. {
    Write_Tag -Tag li -TagData "class='has-sub'" -Content (
        (Write_Tag -Tag "A" -TagData "href='#'" -content (
            Write_Tag -Tag "SPAN" -Content "About"
        )),
        (Write_Tag -Tag UL -TagData "class='has-sub'" -Content (
            Write_Tag -Tag LI -TagData "class='last'" -CONTENT (
                (Write_Tag -Tag "A" -TagData "href='/home?App=About,ThisSystem'" -content (
                    Write_Tag -Tag "SPAN" -Content "This System"
                ))
            )
        ))
    )
    gci "$Global:ScriptFolder\Apps" *.ps1 | ?{-not ($_.name -match '^Menu$')} | %{
        $Appname = $_.name -replace '\.ps1$'
        Write_Tag -Tag "A" -TagData "href='/home?App=$Appname'" -content "$Appname<BR>"
    }
    Write_Tag -Tag li -Content (
        Write_Tag -Tag "A" -TagData "ID='Logon' href=/?App=Logon" -content (
            Write_Tag -Tag "SPAN" -Content "Logon"
        )
    )
    Write_Tag -Tag li -Content (
        Write_Tag -Tag "A" -TagData "ID='Logoff' href=/?App=Logoff" -content (
            Write_Tag -Tag "SPAN" -Content "Logoff"
        )
    )
    Write_Tag -Tag li -Content (
        Write_Tag -Tag "A" -TagData "ID='Exit' href=/?command=quit" -content (
            Write_Tag -Tag "SPAN" -Content "Exit"
        )
    )
    Write_Tag -Tag li -Content (
        (
            Write_Tag -Tag h3 -Content 'Settings'),
            (Write_Tag -Tag ol -TagData " class='menu' style='float:left'" -Content (
                Write_Tag -Tag li -Content (
                    Write_Tag -Tag A -TagData "ID='LoadTheme_Blue1' href=/home?ParamName=Theme&ParamSet=Blue1&command=run&App=ControlPannel" -content (
                        Write_Tag -Tag "SPAN" -Content "Theme Blue1"
                    )
                )
            )
        )
    )
}) -join "`n"
'<img src="/img/powershell-icon-152-191890.png"/>'
'</ul>'

