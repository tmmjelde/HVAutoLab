rem it's a good idea to remove the unattend.xml file because it contains passwords etc. Good practice even though this is a lab.
del %WINDIR%\Panther\unattend.xml %SYSTEMDRIVE%\unattend.xml /s /f
powershell.exe -executionpolicy bypass -file c:\temp\Script.ps1