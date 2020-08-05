 
    Import-DscResource -Module PSDesiredStateConfiguration

    Node $ComputerName
    {  #https://docs.microsoft.com/en-us/powershell/dsc/fileresource
        File CreateDirectory {
            Ensure = "Present" 
            Type = "Directory"
            DestinationPath = "C:\temp\"    
        }

        File CopyFile {
            DependsOn = "[File]CreateDirectory"
            Ensure = "Present" 
            Type = "File" 
            SourcePath = $SourceFile
            DestinationPath = $DestinationFile	
        } 
    }
}

#Generate the MOF for the configuration. Pass required parameters into the DeployFile Configuration.
DeployFile -SourceFile "\\dc1\share\test.txt" -DestinationFile "C:\temp\test.txt" -ComputerName "DSCSQL1" -OutputPath "C:\DeployFile\" 
notepad "C:\DeployFile\DSCSQL1.mof"

#Push the MOF to the target, wait for the operation to complete. Force will replace any existing configuration.
Start-DscConfiguration -Path C:\DeployFile\ -ComputerName "DSCSQL1" -Wait -Verbose -Force
Invoke-Item "\\DSCSQL1\C$\temp"

#Test the DSC configuration. This is checking to see if the system is in the desiered state.
Invoke-Command -ComputerName "DSCSQL1" -ScriptBlock { Test-DscConfiguration -Detailed } | Select-Object * 



#Let's do another computer!
DeployFile -SourceFile "\\dc1\share\test.txt" -DestinationFile "C:\temp\test.txt" -ComputerName "DSCSQL2" -OutputPath "C:\DeployFile\"
Start-DscConfiguration -Path C:\DeployFile\ -ComputerName "DSCSQL2"  -Wait -Verbose -Force
Invoke-Command -ComputerName "DSCSQL2" -ScriptBlock { Test-DscConfiguration -Detailed } | Select-Object * 
Invoke-Item "C:\DeployFile"
