# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                                         #
#                                                                                                         #
#      ██████  █    ██  ██▓███  ▓█████  ██▀███     ▄▄▄█████▓▓█████  ██▓     ███▄    █ ▓█████▄▄▄█████▓     #
#    ▒██    ▒  ██  ▓██▒▓██░  ██▒▓█   ▀ ▓██ ▒ ██▒   ▓  ██▒ ▓▒▓█   ▀ ▓██▒     ██ ▀█   █ ▓█   ▀▓  ██▒ ▓▒     #
#    ░ ▓██▄   ▓██  ▒██░▓██░ ██▓▒▒███   ▓██ ░▄█ ▒   ▒ ▓██░ ▒░▒███   ▒██░    ▓██  ▀█ ██▒▒███  ▒ ▓██░ ▒░     #
#      ▒   ██▒▓▓█  ░██░▒██▄█▓▒ ▒▒▓█  ▄ ▒██▀▀█▄     ░ ▓██▓ ░ ▒▓█  ▄ ▒██░    ▓██▒  ▐▌██▒▒▓█  ▄░ ▓██▓ ░      #
#    ▒██████▒▒▒▒█████▓ ▒██▒ ░  ░░▒████▒░██▓ ▒██▒     ▒██▒ ░ ░▒████▒░██████▒▒██░   ▓██░░▒████▒ ▒██▒ ░      #
#    ▒ ▒▓▒ ▒ ░░▒▓▒ ▒ ▒ ▒▓▒░ ░  ░░░ ▒░ ░░ ▒▓ ░▒▓░     ▒ ░░   ░░ ▒░ ░░ ▒░▓  ░░ ▒░   ▒ ▒ ░░ ▒░ ░ ▒ ░░        #
#    ░ ░▒  ░ ░░░▒░ ░ ░ ░▒ ░      ░ ░  ░  ░▒ ░ ▒░       ░     ░ ░  ░░ ░ ▒  ░░ ░░   ░ ▒░ ░ ░  ░   ░         #
#    ░  ░  ░   ░░░ ░ ░ ░░          ░     ░░   ░      ░         ░     ░ ░      ░   ░ ░    ░    ░           #
#         ░     ░                 ░  ░   ░                    ░  ░    ░  ░         ░    ░  ░              #
#                                                                                                         #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

<#
    v.2020-10-01

    Telnet & Ping in PowerShell

    supertelnet [-src] -srv [-port] [-ping] [-dns] [-timeout]

    [-src]     Name or IP address of the source machine from which the connection attempt will be made.
               If not provided, or if src='.' or src='localhost', the connection will be initiated from the local machine.

    -srv       Name or IP address of the destination machine.

    [-port]    Port on the destination machine. Not required with the -ping switch.
               Options:
               - Specifying a single port. Only the specified port will be tested, e.g., -port 10.
               - Specifying a range of ports. All ports in the range will be tested, e.g., -port 10:20.
               - Specifying a range of ports and a step. Ports within the range will be tested at the specified step,
                   e.g., -port 10:20:3 will test every third port in the range 10:20, always including the end port.

    [-ping]    ICMP ping mode switch.

    [-dns]     DNS name resolution switch. May increase response time. Disabled by default.
               If provided, the script will try to resolve IP addresses to DNS names.

    [-timeout] Wait time for a response from the target server (default is 50ms).



    Examples

    - Ping from localhost
    supertelnet -srv 10.66.3.22 -ping
    supertelnet -srv "machine" -ping

    - Ping from a remote machine
    supertelnet -src "10.66.3.61" -srv 10.66.3.22 -ping
    supertelnet -src "machine" -srv 10.66.3.22 -ping
    supertelnet -src "10.66.3.61" -srv "machine" -ping
    supertelnet -src "machine1" -srv "machine2" -ping

    - Telnet from the local machine
    supertelnet -srv "192.168.224.81" -port 4000
    supertelnet -srv "machine" -port 4000

    - Telnet from a remote machine
    supertelnet -src "10.66.197.216" -srv "192.168.224.81" -port 4000
    supertelnet -src "10.66.197.216" -srv "machine" -port 4000
    supertelnet -src "machine" -srv "192.168.224.81" -port 4000
    supertelnet -src "machine1" -srv "machine2" -port 4000

    - Telnet on a range of ports
    supertelnet -srv "192.168.224.81" -port 4000:4005

    - Telnet on a range of ports with a step
    supertelnet -srv "192.168.224.81" -port 4000:5000:150

    - DNS name resolution
    supertelnet -src "10.66.3.61" -srv 10.66.3.22 -ping -dns
    supertelnet -src "10.66.197.216" -srv "192.168.224.81" -port 4000 -dns
#>

function revDNS($txt) {
    if ($txt -match "^[\d\.]+$") {
        try { $txt = [System.Net.Dns]::GetHostEntry($txt).HostName }
        catch {}
    }
    return $txt.ToUpper()
}
function getIP($txt) {
    if ($txt -match "^[\d\.]+$") { return $txt }
    try { $ip = (Resolve-DnsName -Name $txt -ErrorAction Stop).IP4Address }
    catch {
        $msg = $src + ": DNS name " + $srv + " does not exist"
        Write-Host -ForegroundColor Cyan $msg
        return 0
    }
    return $ip
}
function tcpconnect($srv, $port, $timeout, $dns) {
    $src = (Get-WmiObject -Class Win32_ComputerSystem -Property Name).Name.ToUpper()
    $srv = $srv.ToUpper()
    $srcip = getIP -txt $src
    $srvip = getIP -txt $srv
    if ($srvip -ne 0) {
        $requestCallback = $state = $null
        $client = New-Object System.Net.Sockets.TcpClient
        $beginConnect = $client.BeginConnect($srv, $port, $requestCallback, $state)
        Start-Sleep -milli $timeOut
        if ($client.Connected) { $status = "Open" } else { $status = "Closed" }
        $client.Close()
        if ($dns) {
            $src = revDNS -txt $src
            $srv = revDNS -txt $srv
        }
        $msg = $src + "->" + $srv + " | " + $srcip + "->" + $srvip
        $msg = $msg + " | Port: " + $port + " | " + $status
        if ($status -eq "Open") { Write-Host -ForegroundColor Green $msg } else { Write-Host -ForegroundColor Red $msg }
    }
}
function icmpping($srv, $dns) {
    $src = (Get-WmiObject -Class Win32_ComputerSystem -Property Name).Name.ToUpper()
    $srv = $srv.ToUpper()
    $srcip = getIP -txt $src
    $srvip = getIP -txt $srv
    if ($srvip -ne 0) {
        $status = Test-Connection -ComputerName $srv -Count 1 -Quiet
        if ($dns) {
            $src = revDNS -txt $src
            $srv = revDNS -txt $srv
        }
        $msg = $src + "->" + $srv + " | " + $srcip + "->" + $srvip
        $msg = $msg + " | PING " + $status
        if ($status) { Write-Host -ForegroundColor Green $msg } else { Write-Host -ForegroundColor Red $msg }
    }
}
$revDNS = "function revDNS { ${function:revDNS} }"
$getIP = "function getIP { ${function:getIP} }"
$tcpconnect = "function tcpconnect { ${function:tcpconnect} }"
$icmpping = "function icmpping { ${function:icmpping} }"
function supertelnet {
    param (
        $src=".",
        $srv,
        $port,
        $timeout=50,
        [switch]$ping,
        [switch]$dns=$false
    )

    $everyport = 1
    if ($port -like "*:*:*") {
        $startport = [convert]::ToInt32($port.split(":")[0],10)
        $endport = [convert]::ToInt32($port.split(":")[1],10)
        $everyport = [convert]::ToInt32($port.split(":")[2],10)
    }
    elseif ($port -like "*:*") {
        $startport = [convert]::ToInt32($port.split(":")[0],10)
        $endport = [convert]::ToInt32($port.split(":")[1],10)
    }
    else {
        $startport = $endport = [int]$port
    }

    if ($src -eq "." -or  $srv -eq "localhost") {
        if ($ping.IsPresent) {
            icmpping -srv $srv
        }
        else {
            for ($port=$startport; $port -le $endport; $port++) {
                tcpconnect -srv $srv -port $port -timeout $timeout
            }
        }
    }
    else {
        $src = revDNS($src)
        if ($ping.IsPresent) {
            try {
                Invoke-Command -ComputerName $src -ArgumentList $revDNS,$getIP,$icmpping,$srv,$dns -ErrorAction Stop -ScriptBlock {
                    . ([ScriptBlock]::Create($using:revDNS))
                    . ([ScriptBlock]::Create($using:getIP))
                    . ([ScriptBlock]::Create($using:icmpping))
                    icmpping -srv $using:srv -dns $using:dns
                }
            }
            catch {
                $msg = "Cannot connect to remote server " + $src
                Write-Host -ForegroundColor Cyan $msg
            }
        }
        else {
            $port = $startport
            while ($port -le $endport) {
                try {
                    Invoke-Command -ComputerName $src -ArgumentList $revDNS,$getIP,$tcpconnect,$srv,$port,$timeout,$dns -ErrorAction Stop -ScriptBlock {
                        . ([ScriptBlock]::Create($using:revDNS))
                        . ([ScriptBlock]::Create($using:getIP))
                        . ([ScriptBlock]::Create($using:tcpconnect))
                        tcpconnect -srv $using:srv -port $using:port -timeout $using:timeout -dns $using:dns
                    }
                }
                catch {
                    $msg = "Cannot connect to remote server " + $src
                    Write-Host -ForegroundColor Cyan $msg
                }
                $port += $everyport
                if ($everyport -ne 1 -and $port -gt $endport) {
                    if ($port - $everyport -ne $endport) {
                        $port = $endport
                        $everyport = 1
                    }
                }
            }
        }
    }
}
