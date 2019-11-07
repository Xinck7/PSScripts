#this is a powershell file so you can use regions to look at the notes
#control M in ISE

#region Windows troubleshooting and configuration Notes

#DNS Troubleshooting notes
<#
for troubleshooting DNS
http://www.chicagotech.net/dnstroubleshooting.htm 
#>

#Getting to know OS notes
<#

    How to install the OS
    How to manage disks. How to mount a disk, extend a volume, etc
    How to manage users and groups.
    How to configure TCP/IP settings
    How to configure a firewall
    How to stop and start a service, and how to set a service to start at boot
    How to look at running processes and kill a particular process
    How to securely connect to the machine running the OS and remotely manage it
    How to script all these things using a language native to that OS
    How to make some basic security changes (stop unnecessary services, disable a guest user, secure the default "admin" account, etc)
    How to install packages

#>

#Bios for Dell notes
<#
To switch/ strip Dell or go to dell branded 

Dell has no ID Module native to their devices

OEM has an ID module that is loaded on 


for 13G boxes (likely 14G+) this can be loaded in the idrac settings
need a .pm file that comes from the exe that is not for windows and has the BSU on it

1. Get idrac up and running somehow (either ip route work around or through another cable w/e - don't use dup IP - learned the hard way)
2. ssh to idrac
3. Get service tag
4. on Dell's website look up the service tag for drivers and downloads
5. download the cust.bsu file (unpackged/board service utility)
6. extract the file (.pm)
7. Go to update +rollback under idrac settings
8. Upload the PM file
9. click install
10. Go to job queue from overview and then job queue
11. wait for it to say complete
12. go back to server overview and click reset idrac
13. clear browser cache (actually important tried not before)
14. wait for the idrac to come back online with the uploaded ID module 
15. profit

DBE is its own module that allows for embedded microsoft OS's to work properly

there is no difference aside from DBE on the model name and a dell branded aside from it having a module

One can go between DBE and OEM easily through the iDRAC so long as there is accessibility to that

You can change what the native interface is on it and trick the OS into thinking its plugged in if you wanted to just jump the cables in the back

__________________________
From Dell

"Chris - thanks for confirming.

The only other differences between the DBE system you now have and a standard Dell system (with no IDM at all on the system are).

1) The fact that there is an ID Module installed on your DBE system. This doesn't change any functionality however. Standard Dell systems don't have any ID Module. But because of this IDM, SMBIOS Type 11 has additional data populated. Most customers don't even notice this.

2) Your system has OS activation for Dell Embedded Windows and not Dell Standard Windows. This actually happened not because of the DBE IDM I gave you - but because your system was originally OEMReady. If you don't use Windows - this shouldn't affect you.

Hope this helps.
Dell named employee"

___________________
Other findings from it

name in devince = or the network script causes the naming to be different separately
delete persist net rules to change it from one to the other
Here we go.  (And ya may wanna jot this down, cuz I didn’t see one single page explaining it all.)

Short version:  It’s software in your initrd image.  I wanna see what your wonky system’s initturd looks like.sa

Extract boot image into temporary directory:
# zcat /boot/initramfs-2.6.32-431.3.1.el6.x86_64.img |cpio -idmv

Look for “biosdevname” in the image:
# grep -Rl biosdevname *
etc/udev/rules.d/71-biosdevname.rules
pre-trigger/30parse-biosdevname.sh
sbin/biosdevname

Determine our “sys_vendor” built earlier by dmidecode as part of startup:
# cat /sys/class/dmi/id/sys_vendor
Dell Inc.


# cat pre-trigger/30parse-biosdevname.sh
USE_BIOSDEVNAME=$(getarg biosdevname)   <-- pulls boot line setting in if it was entered
if [ "$USE_BIOSDEVNAME" = "0" ]; then
    udevproperty UDEV_BIOSDEVNAME=
    rm -f /etc/udev/rules.d/71-biosdevname.rules <-- if “biosdevname=0” was FORCED from boot, delete “71-biosdevname.rules” 
elif [ "$USE_BIOSDEVNAME" = "1" ]; then
    info "biosdevname=1: activating biosdevname network renaming"
    udevproperty UDEV_BIOSDEVNAME=1
fi


# cat etc/udev/rules.d/71-biosdevname.rules  <-- Is run if (“biosdevname=1” on boot line) or (no bootline setting)
SUBSYSTEM!="net", GOTO="netdevicename_end"
KERNEL!="eth*",   GOTO="netdevicename_end"
ACTION!="add",    GOTO="netdevicename_end"
NAME=="?*",       GOTO="netdevicename_end"

# whitelist all Dell systems
ATTR{[dmi/id]sys_vendor}=="Dell*", ENV{UDEV_BIOSDEVNAME}="1"  <-- bingo

# kernel command line "biosdevname={0|1}" can turn off/on biosdevname
IMPORT{cmdline}="biosdevname"
ENV{biosdevname}=="?*", ENV{UDEV_BIOSDEVNAME}="$env{biosdevname}"
# ENV{UDEV_BIOSDEVNAME} can be used for blacklist/whitelist
# but will be overwritten by the kernel command line argument
ENV{UDEV_BIOSDEVNAME}=="0", GOTO="netdevicename_end"
ENV{UDEV_BIOSDEVNAME}=="1", GOTO="netdevicename_start"

# off by default
GOTO="netdevicename_end"

LABEL="netdevicename_start"

# using NAME= instead of setting INTERFACE_NAME, so that persistent
# names aren't generated for these devices, they are "named" on each boot.
PROGRAM="/sbin/biosdevname --smbios 2.6 --nopirq --policy physical -i %k", NAME="%c",  OPTIONS+="string_escape=replace"

LABEL="netdevicename_end"

----You can add a line that says * vendor and it will boot as such if soft fix is ideal that isn't in the name---------
#>

#Service Notes
<#
Sc queryex <name>
Taskkill /f /pid <number>
#>

#endregion Windows troubleshooting and configuration Notes

#region Syslog Notes
#Syslog stuff learned
<#

If you have bash version 2.04+ compiled with --enable-net-redirections (it isn’t compiled this way in Debian and derivatives), you can use bash itself. The following example is also used in Finding My IP Address:

$ exec 3<> /dev/tcp/www.ippages.com/80
$ echo -e "GET /simple/?se=1 HTTP/1.0\n" >&3
$ cat <&3
HTTP/1.1 200 OK
Date: Tue, 28 Nov 2006 08:13:08 GMT
Server: Apache/2.0.52 (Red Hat)
X-Powered-By: PHP/4.3.9
Set-Cookie: smipcomID=6670614; expires=Sun, 27-Nov-2011 08:13:09 GMT; path=/
Pragma: no-cache
Cache-Control: no-cache, must-revalidate
Content-Length: 125
Connection: close
Content-Type: text/plain; charset=ISO-8859-1

72.NN.NN.225 (US-United States) http://www..com Tue, 28 Nov 2006 08:13:09 UTC/GMT
flagged User Agent - reduced functionality
WARNING
As noted, this recipe will probably not work under Debian and derivatives such as Ubuntu since they expressly do not compile bash with --enable-net-redirections.

Discussion
As noted in Redirecting Output for the Life of a Script, it is possible to use exec to permanently redirect file handles within the current shell session, so the first command sets up input and output on file handle 3. The second line sends a trivial command to a path on the web server defined in the first command. Note that the user agent will appear as “-” on the web server side, which is what is causing the “flagged User Agent” warning. The third command simply displays the results.

Both TCP and UDP are supported. Here is a trivial way to send syslog messages to a remote server (although in production we recommend using the logger utility, which is much more user friendly and robust):

echo "<133>${0##*/}[$$]: Test syslog message from bash" > /dev/udp/loghost.example.com/514
#####
Secret sauce:
Since UDP is connectionless, this is actually much easier to use than the previous TCP example. <133> is the syslog priority value for local0.notice, calculated according to RFC 3164. See the RFC “4.1.1 PRI Part” and logger manpage for details. $0 is the name, so ${0##*/} is the “basename” and $$ is the process ID of the current program. The name will be -bash for a login shell.

$ logger -p local0.notice -t ${0##*/}[$$] test message
Netcat is known as the “TCP/IP Swiss Army knife” and is usually not installed by default. It may also be prohibited as a hacking tool by some security policies, though bash’s net-redirection features do pretty much the same thing. See the discussion in Using bash Net-Redirection for details on the <133>${0##*/}[$$] part.

# Netcat
$ echo "<133>${0##*/}[$$]: Test syslog message from Netcat" | nc -w1 -u loghost 514

# bash
$ echo "<133>${0##*/}[$$]: Test syslog message from bash" \
  > /dev/udp/loghost.example.com/514




#>

#More secret sauce on using syslog
<#
SMS events can be directed to a remote Syslog server. Through the SMS Admin interface, you can configure which events are sent to a remote Syslog server. When you create a new remote Syslog server, you have the option to exclude backlog events.

Each Syslog message includes a priority value at the beginning of the text. The priority value ranges from 0 to 191 and is not space or leading zero padded. The priority is enclosed in "<>" delimiters. E.g. <PRI>HEADER MESSAGE.

The priority value is calculated using the formula (Priority = Facility * 8 + Level). For example, a kernel message (Facility=0) with a Severity of Emergency (Severity=0) would have a Priority value of 0. Also, a "local use 4" message (Facility=20) with a Severity of Notice (Severity=5) would have a Priority value of 165.

Syslog Facilities

The facility represents the machine process that created the syslog event. For example, is the event created by the kernel, by the mail system, by security/authorization processes, etc.? In the context of this field, the facility represents a kind of filter, instructing SMS to forward to the remote Syslog Server only those events whose facility matches the one defined in this field. So by changing the facility number and/or the severity level you change the amount of alerts (messages) that are sent to the remote syslog server

The Facility value is a way of determining which process of the machine created the message. Since the Syslog protocol was originally written on BSD Unix, the Facilities reflect the names of UNIX processes and Daemons.

List of available Facilities as per RFC5424:
Facility Number	Facility Description	Facility Number	Facility Description
0	kernel messages	12	NTP subsystem
1	user-level messages	13	log audit
2	mail system	14	log alert
3	system daemons	15	clock daemon
4	**security/authorization messages	16	local use 0 (local0)
5	messages generated internally by syslog	17	local use 1 (local1)
6	line printer subsystem	18	local use 2 (local2)
7	network news subsystem	19	local use 3 (local3)
8	UUCP subsystem	20	local use 4 (local4)
9	clock daemon	21	local use 5 (local5)
10	security/authorization messages	22	local use 6 (local6)
11	FTP daemon	23	local use 7 (local7)
** SMS default
Note: Items in yellow are the facility numbers available on the SMS.


If you are receiving messages from a UNIX system, it is suggested you use the “User” Facility as your first choice. Local0 through to Local7 are not used by UNIX and are traditionally used by networking equipment. Cisco routers for example use Local6 or Local7.

Syslog Severity Levels

Recommended practice is to use the Notice or Informational level for normal messages.

Explanation of the severity Levels:
SEVERITY LEVEL	EXPLANATION
**	SEVERITY IN EVENT	Default SMS setting for Syslog Security option. This setting will send all events to remote Syslog system
0	EMERGENCY	A "panic" condition - notify all tech staff on call? (Earthquake? Tornado?) - affects multiple apps/servers/sites.
1	ALERT	Should be corrected immediately - notify staff who can fix the problem - example is loss of backup ISP connection.
2	CRITICAL	Should be corrected immediately, but indicates failure in a primary system - fix CRITICAL problems before ALERT - example is loss of primary ISP connection.
3	ERROR	Non-urgent failures - these should be relayed to developers or admins; each item must be resolved within a given time.
4	WARNING	Warning messages - not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time.
5	NOTICE	Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required.
6	INFORMATIONAL	Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required.
7	DEBUG	Info useful to developers for debugging the app, not useful during operations.
** SMS default
#>
#endregion Syslog Notes