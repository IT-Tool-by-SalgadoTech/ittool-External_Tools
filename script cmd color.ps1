param([ValidateSet('menu','orange','green','restore')] [string]$Mode='menu')
$ORANGE_BGR=0x0000C2FF
$GREEN_BGR=0x00008000
$BLACK=0x00000000

function Set-ConHost-HKU {
    param([string]$Sid,[ValidateSet('orange','green','restore')]$Mode)
    $base="Registry::HKEY_USERS\$Sid\Console"
    if(-not(Test-Path $base)){New-Item -Path $base -Force|Out-Null}
    switch($Mode){
        'orange'{
            New-ItemProperty -Path $base -Name ScreenColors -PropertyType DWord -Value 0x06 -Force|Out-Null
            New-ItemProperty -Path $base -Name PopupColors -PropertyType DWord -Value 0x06 -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable6 -PropertyType DWord -Value $ORANGE_BGR -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable0 -PropertyType DWord -Value $BLACK -Force|Out-Null
        }
        'green'{
            New-ItemProperty -Path $base -Name ScreenColors -PropertyType DWord -Value 0x02 -Force|Out-Null
            New-ItemProperty -Path $base -Name PopupColors -PropertyType DWord -Value 0x02 -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable2 -PropertyType DWord -Value $GREEN_BGR -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable0 -PropertyType DWord -Value $BLACK -Force|Out-Null
        }
        'restore'{
            New-ItemProperty -Path $base -Name ScreenColors -PropertyType DWord -Value 0x07 -Force|Out-Null
            New-ItemProperty -Path $base -Name PopupColors -PropertyType DWord -Value 0xF5 -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable0 -PropertyType DWord -Value 0x00000000 -Force|Out-Null
            New-ItemProperty -Path $base -Name ColorTable7 -PropertyType DWord -Value 0x00C0C0C0 -Force|Out-Null
            foreach($i in 0..15){
                if($i -ne 0 -and $i -ne 7){
                    $ct="ColorTable$($i)"
                    if(Get-ItemProperty -Path $base -Name $ct -ErrorAction SilentlyContinue){
                        Remove-ItemProperty -Path $base -Name $ct -Force
                    }
                }
            }
        }
    }

    foreach($sub in '%SystemRoot%_system32_cmd.exe','%SystemRoot%_SysWOW64_cmd.exe'){
        $k=Join-Path $base $sub
        if(-not(Test-Path $k)){New-Item -Path $k -Force|Out-Null}
        switch($Mode){
            'orange'{
                New-ItemProperty -Path $k -Name ScreenColors -PropertyType DWord -Value 0x06 -Force|Out-Null
                New-ItemProperty -Path $k -Name PopupColors -PropertyType DWord -Value 0x06 -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable6 -PropertyType DWord -Value $ORANGE_BGR -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable0 -PropertyType DWord -Value $BLACK -Force|Out-Null
            }
            'green'{
                New-ItemProperty -Path $k -Name ScreenColors -PropertyType DWord -Value 0x02 -Force|Out-Null
                New-ItemProperty -Path $k -Name PopupColors -PropertyType DWord -Value 0x02 -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable2 -PropertyType DWord -Value $GREEN_BGR -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable0 -PropertyType DWord -Value $BLACK -Force|Out-Null
            }
            'restore'{
                New-ItemProperty -Path $k -Name ScreenColors -PropertyType DWord -Value 0x07 -Force|Out-Null
                New-ItemProperty -Path $k -Name PopupColors -PropertyType DWord -Value 0xF5 -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable0 -PropertyType DWord -Value 0x00000000 -Force|Out-Null
                New-ItemProperty -Path $k -Name ColorTable7 -PropertyType DWord -Value 0x00C0C0C0 -Force|Out-Null
                foreach($i in 0..15){
                    if($i -ne 0 -and $i -ne 7){
                        $ct="ColorTable$($i)"
                        if(Get-ItemProperty -Path $k -Name $ct -ErrorAction SilentlyContinue){
                            Remove-ItemProperty -Path $k -Name $ct -Force
                        }
                    }
                }
            }
        }
    }
}

function Upsert-Prop([object]$obj,[string]$name,$value){
    if($obj.PSObject.Properties.Match($name).Count -eq 0){
        Add-Member -InputObject $obj -NotePropertyName $name -NotePropertyValue $value -Force
    } else {
        $obj.$name=$value
    }
}

function Patch-WT-Settings{
    param([string]$SettingsPath,[ValidateSet('orange','green','restore')]$Mode)
    try{$j=Get-Content $SettingsPath -Raw|ConvertFrom-Json}catch{return}
    if(-not $j){return}
    if(-not $j.profiles){
        Add-Member -InputObject $j -NotePropertyName profiles -NotePropertyValue (@{defaults=@{};list=@()})
    }
    $defaults=$null; $list=@()
    if($j.profiles -isnot [System.Array]){
        if(-not $j.profiles.defaults){$j.profiles.defaults=@{}}
        $defaults=$j.profiles.defaults
        if($j.profiles.list){$list=$j.profiles.list}
    }
    switch($Mode){
        'orange'{
            if($defaults){
                Upsert-Prop $defaults 'foreground' '#FFC200'
                Upsert-Prop $defaults 'background' '#000000'
                if($defaults.PSObject.Properties.Match('colorScheme').Count){$defaults.PSObject.Properties.Remove('colorScheme')|Out-Null}
            }
            foreach($p in $list){
                $isCmd=($p.commandline -match 'cmd\.exe') -or ($p.name -match 'Command\s*Prompt')
                $isPs=($p.commandline -match 'powershell\.exe') -or ($p.name -match 'Windows\s*PowerShell')
                if($isCmd -or $isPs){
                    Upsert-Prop $p 'foreground' '#FFC200'
                    Upsert-Prop $p 'background' '#000000'
                    if($p.PSObject.Properties.Match('colorScheme').Count){$p.PSObject.Properties.Remove('colorScheme')|Out-Null}
                }
            }
        }
        'green'{
            if($defaults){
                Upsert-Prop $defaults 'foreground' '#008000'
                Upsert-Prop $defaults 'background' '#000000'
                if($defaults.PSObject.Properties.Match('colorScheme').Count){$defaults.PSObject.Properties.Remove('colorScheme')|Out-Null}
            }
            foreach($p in $list){
                $isCmd=($p.commandline -match 'cmd\.exe') -or ($p.name -match 'Command\s*Prompt')
                $isPs=($p.commandline -match 'powershell\.exe') -or ($p.name -match 'Windows\s*PowerShell')
                if($isCmd -or $isPs){
                    Upsert-Prop $p 'foreground' '#008000'
                    Upsert-Prop $p 'background' '#000000'
                    if($p.PSObject.Properties.Match('colorScheme').Count){$p.PSObject.Properties.Remove('colorScheme')|Out-Null}
                }
            }
        }
        'restore'{
            if($defaults){
                foreach($n in 'foreground','background','colorScheme'){
                    if($defaults.PSObject.Properties.Match($n).Count){$defaults.PSObject.Properties.Remove($n)|Out-Null}
                }
            }
            foreach($p in $list){
                foreach($n in 'foreground','background','colorScheme'){
                    if($p.PSObject.Properties.Match($n).Count){$p.PSObject.Properties.Remove($n)|Out-Null}
                }
            }
        }
    }
    ($j|ConvertTo-Json -Depth 30)|Set-Content -Path $SettingsPath -Encoding UTF8
}

function Apply-All([ValidateSet('orange','green','restore')]$Mode){
    $loadedSids=@()
    $uKeys=Get-ChildItem Registry::HKEY_USERS|Where-Object{$_.PSChildName -match '^S-1-5-21-.*$' -and $_.PSChildName -notmatch '_Classes$'}
    foreach($k in $uKeys){$loadedSids+=$k.PSChildName}
    foreach($sid in $loadedSids){Set-ConHost-HKU -Sid $sid -Mode $Mode}
    $profileRoots=@()
    foreach($sid in $loadedSids){
        try{
            $pi=Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -ErrorAction Stop
            if($pi.ProfileImagePath -and (Test-Path $pi.ProfileImagePath)){$profileRoots+=$pi.ProfileImagePath}
        }catch{}
    }
    $profileRoots=$profileRoots|Select-Object -Unique
    foreach($root in $profileRoots){
        $cand=@(
            (Join-Path $root 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $root 'AppData\Local\Microsoft\Windows Terminal\settings.json'),
            (Join-Path $root 'AppData\Local\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
        )
        foreach($f in $cand){if(Test-Path $f){Patch-WT-Settings -SettingsPath $f -Mode $Mode}}
    }
}

function Show-Menu{
    Clear-Host
    Write-Host "=== Console Colors - All-in-One ==="
    Write-Host "1) Orange (bright)  [#FFC200]"
    Write-Host "2) Dark Green       [#008000]"
    Write-Host "3) Restore defaults"
    Write-Host "4) Exit"
    $c=Read-Host "Choose [1-4]"
    switch($c){
        '1'{Apply-All -Mode 'orange'; Write-Host "Orange applied. Reopen consoles."}
        '2'{Apply-All -Mode 'green'; Write-Host "Green applied. Reopen consoles."}
        '3'{Apply-All -Mode 'restore'; Write-Host "Defaults restored. Reopen consoles."}
        '4'{return}
        default{Write-Host "Invalid option."}
    }
    Pause
    Show-Menu
}

if($Mode -eq 'menu'){Show-Menu}else{Apply-All -Mode $Mode}
