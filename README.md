# DoRemotely
The PowerShell script processes the collection of hosts and on each runs dolets (powershell scripts) via PSSession.
Each dolet returns the result of its work. The results are saved in files and in the summary report.

## Requirements for use:
* PowerShell V3
* Necessary rights to pull information from remote hosts
* [PoshRSJob](https://github.com/proxb/PoshRSJob) module to assist with data gathering
