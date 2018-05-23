# DoRemotely
This PowerShell script handles the collection of hosts, running 'dolets' (powershell scripts) through PSSession on each one.
The results of run are returned be every 'dolet' instance. Then results are saved to file and summary report.

## Requirements for use:
* PowerShell V3
* Necessary rights to pull information from remote hosts
* [PoshRSJob](https://github.com/proxb/PoshRSJob) module to assist with data gathering
