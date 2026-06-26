$Inventory = @()
$WindowsIP = @()
$LinuxIP = @()
$HardwareIP = @()
$sessions = @()
$Results = @()
$wincred = $null
$linuxcred = $null

# Get the IPv4 address of your active internet connection
$MyIP = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" } |
        Select-Object -First 1 -ExpandProperty IPAddress

# Split the string into 4 octets and then keep the first 3
$Octets = $MyIP.Split('.')
$Subnet = "$($Octets[0]).$($Octets[1]).$($Octets[2])."

Write-Host "Local subnet set to $Subnet"

# Ping Sweep with OS Fingerprinting
foreach ($i in 1..255) {

    #IMPORTANT: Manual vs Automatic Subnet Selection
    #IMPORTANT: If you want to manually set a subnet, you can uncomment and edit the line below, but you MUST comment out the other $IP declaration.
    #$IP = "192.168.1.$i"
    $IP = "$Subnet$i"

    Write-Host "Scanning $IP"

    $ping = Test-Connection -ComputerName $IP -Count 1 -ErrorAction SilentlyContinue

    if ($ping) {

        $ttl = $ping.ResponseTimeToLive

        $OS = if ($ttl -le 64) { "Linux" }
              elseif ($ttl -le 128) { "Windows" }
              else { "Hardware" }

        $FoundDevice = [PSCustomObject]@{
            IP     = $IP
            TTL    = $ttl
            Status = "Online"
            OS     = $OS
        }

        $Inventory += $FoundDevice
    }
}

#Sorting the IPs by OS
foreach ($device in $Inventory) {
    if ($device.OS -eq "Windows") {
        $WindowsIP += $device.IP
    }
    elseif ($device.OS -eq "Linux") {
        $LinuxIP += $device.IP
    }
    elseif ($device.OS -eq "Hardware") {
        $HardwareIP += $device.IP
    }
}

Write-Host "Ping sweep completed against $($Subnet)0/24 subnet. $($Inventory.Count) devices detected."
Write-Host "$($WindowsIP.Count) were Windows, $($LinuxIP.Count) were Linux, and $($HardwareIP.Count) were network hardware"

# Export Linux IPs
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$LinuxExportName = "EagleEye_LinuxIPs_$Timestamp.txt"
$LinuxIP | Out-File $LinuxExportName
Write-Host "Linux IPs exported to $LinuxExportName"

#Main Menu Loop
$rec = Read-Host "Enter a menu option to continue: `n1. Enter Admin Credentials  `n2. Start Windows Test `n3. View Results `n4. Exit"

while ($rec -ne "4") {
    switch ($rec) {

# Creds collection
        "1" {
            Write-Host "Option 1 selected: Enter Admin Credentials"

            $rec2 = Read-Host "Enter a menu option to continue: `n1. Enter Windows Credentials  `n2. Enter Linux Credentials  `n3. Exit"

            if ($rec2 -eq "1") {
                Write-Host "Option 1 selected: Enter Admin Windows Credentials"
                $wincred = Get-Credential
            }
            elseif ($rec2 -eq "2") {
                Write-Host "Option 2 selected: Enter Admin Linux Credentials"
                $linuxcred = Get-Credential
            }
            elseif ($rec2 -eq "3") {
                Write-Host "Exiting credential entry menu."
            }
            else {
                Write-Host "Invalid option, please try again."
            }
        }

# Windows Execution Loop Start
        "2" {
            if ($null -eq $wincred) {
                Write-Host "Access Denied: No credentials found. Returning to menu..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                break
            }

            Write-Host "Option 2 selected: Start Test"

            if ($WindowsIP.Count -gt 0) {

                Write-Host "Starting tests against Windows devices..."

                $Results = @()
                $sessions = @()

#Iterate through each IP, start a session using windows creds, and invoke commands on each session.
                foreach ($ip in $WindowsIP) {
                    Write-Host "Creating new session with $ip"

                    $newSession = New-PSSession -ComputerName $ip -Credential $wincred -ErrorAction SilentlyContinue

                    if ($newSession) {
                        $sessions += $newSession
                        Write-Host "Another session added, total sessions: $($sessions.Count)"
                    }
                    else {
                        Write-Host "Failed to create session with $ip" -ForegroundColor Yellow

                        $Results += "=============================="
                        $Results += "IP ADDRESS: $ip"
                        $Results += "STATUS: FAILED"
                        $Results += "=============================="
                        $Results += ""
                    }
                }

                foreach ($session in $sessions) {
                    Write-Host "Connecting to $($session.ComputerName) and running commands..."

                    try {
                        $CommandOutput = Invoke-Command -Session $session -ErrorAction Stop -ScriptBlock {

                            Write-Output "=============================="
                            Write-Output "STATUS: PASSED"
# Commands to be executed on remote host                             
                            Write-Output "=== HOST INFORMATION ==="
                            $temp = hostname
                            hostname
                            whoami
                            ipconfig /all
                            systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Boot Time"

                            Write-Output "=== PERSISTENCE ==="
                            Get-WmiObject Win32_StartupCommand | Format-Table Name, Command, Location, User -AutoSize               

                            Write-Output "=== PERSISTENCE - Processes ==="                            
                            Get-Process | Select-Object Name, Id, Path

                            Write-Output "=== Network Connections ==="
                            netstat -ano

                            Write-Output "=== PERSISTENCE - Services ==="
                            Get-CimInstance Win32_Service | Select Name, State, StartMode, PathName | Sort-Object State, Name
                            schtasks /query /fo LIST

                            Write-Output "=== Users/Groups ==="
                            Get-CimInstance Win32_LoggedOnUser
                            net user
                            net localgroup administrators
                            net localgroup "Remote Desktop Users"

                            Write-Output "END OF $temp"
                            Write-Output "=============================="                          
                        }

#Output results to console
                        Write-Host "Results from $($session.ComputerName):"
                        Write-Output $CommandOutput

                        $Results += "REMOTE COMPUTER: $($session.ComputerName)"
                        $Results += $CommandOutput
                        $Results += ""
                    }
                    catch {
                        $Results += "=============================="
                        $Results += "IP ADDRESS: $($session.ComputerName)"
                        $Results += "STATUS: FAILED"
                        $Results += "ERROR: $($_.Exception.Message)"
                        $Results += "=============================="
                        $Results += ""
                    }
                }

# Save results to a timestamped file
                $Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
                $ReportName = "EagleEye_WindowsReport_$Timestamp.txt"

                $Results | Out-File $ReportName

                Write-Host "Sending results to $ReportName"

                foreach ($session in $sessions) {
                    Remove-PSSession $session
                }
            }
            else {
                Write-Host "No Windows devices found to test."
            }
        }

        "3" {
            Write-Host "Option 3 selected: View Results"

            if ($Results.Count -gt 0) {
                Write-Output $Results
            }
            else {
                Write-Host "No results available."
            }
        }

        default {
            Write-Host "Invalid option, please try again."
        }
    }

    $rec = Read-Host "Enter a menu option to continue: `n1. Enter Credentials  `n2. Start Windows Test `n3. View Results `n4. Exit"
}

Write-Host "Exiting EagleEye."