function Get-UserPrompt {
    $StringBuilder = [System.Text.StringBuilder]::new()
    :outer while ($true) {
        #Retrieve from user input
        $ret = Read-Host

        #Break by double line feeds
        if ([string]::IsNullOrEmpty($ret)) {
            break outer
        }
        #break by empty line
        if ($ret -eq '') {
            break outer
        }
        #break by empty line
        if ($ret -eq 'exit') {
            break outer
        }

        #Special commands. (Starts with "#")
        if ($ret.StartsWith('#', [StringComparison]::Ordinal)) {
            switch -Wildcard ($ret.Substring(1).Trim()) {
                'end' {
                    $script:Status = 'exit'
                    return
                }

                'exit' {
                    $script:Status = 'exit'
                    return
                }

                'send' {
                    break outer
                }
            }
        }
        $null = $StringBuilder.AppendLine($ret)
    }
    $StringBuilder.ToString().TrimEnd()
    $StringBuilder.Length = 0
}
