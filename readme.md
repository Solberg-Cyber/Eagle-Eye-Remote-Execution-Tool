** By Dan Solberg **

** In order to run: ** powershell -ExecutionPolicy Bypass -File script.ps1
---
** Purpose of this script: **
	This is my swiss butter knife, which you can use for almost any task.
	This is a remote execution script built and designed for the discovery & counter infiltration steps of the incident response 
	lifecycle. However, this script could easily be adapted to your needs by adding/removing commands to be executed (look for 
	the invoke-command loop) in the script. This script could be especially useful for system administration, or in any task where you 
	wish to make changes to all computers on a subnet at once.
	
---

** Design **
	This script is designed to automate basic network discovery and system data collection within a local subnet. It identifies the 
	host system’s network range, performs a ping sweep to detect active devices, and uses TTL-based fingerprinting to categorize 
	them as Windows, Linux, or network hardware. The script then organizes these results into separate groups and exports Linux IPs for
	potential follow-up actions. Through a menu-driven interface, the user can supply credentials and remotely connect to discovered 
	Windows systems using PowerShell remoting to execute a set of diagnostic and inventory commands. The collected output is compiled 
	a timestamped report, providing a structured snapshot of system information for administrative review or incident response purposes.

---

** Versions **
	The PS5 version is meant to be ran on powershell 5; the PS7 version is meant to be ran on powershell 7 or newer. In powershell 7
	they introduced parallel execution, allowing us to scan 50 or so machines at once instead of being constrained to just one.
	In other words, the primary difference between the two scripts is their speed. The powershell 7 version is much faster.
	
---