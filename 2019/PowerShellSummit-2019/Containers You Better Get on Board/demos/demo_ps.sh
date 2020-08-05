#Pull the PowerShell Core container images for this demo.
docker pull mcr.microsoft.com/powershell:latest
docker pull mcr.microsoft.com/powershell:6.2.0-ubuntu-18.04
docker pull mcr.microsoft.com/powershell:preview

#Let's look at the container image's properties to learn a little about what a container is made of
docker inspect mcr.microsoft.com/powershell:latest | less 

#Shout out to Andrew Pruski (@dbafromthecold) for this little gem...
pwsh
(Invoke-Webrequest https://mcr.microsoft.com/v2/powershell/tags/list).content
exit

#Let's create a PowerShell Container, and attach to the terminal to get a shell
docker run                   \
       --name "pwsh-latest"  \
       --interactive --tty   \
       mcr.microsoft.com/powershell:latest 

#Run these inside the pwsh-lastest container.
Get-Process
"Hello Summiteers" | Out-File -path ~/greetings.txt
Get-Childitem -path ~/
exit

#When we exit, our process terminates and thus our container is no longer running.
docker ps

#Get a list of containers regardless of running state.
docker ps -a

#Let's restart our pwsh-latest container, and attach interactively to it
docker start pwsh-latest -i
Get-Childitem -path ~/
Get-Content -path ~/greetings.txt
exit

#Now that file will go away, it's in the writable layer of the container.
docker rm pwsh-latest

#PowerShell Core 6.2.0, using the latest tag...and passing in a cmdlet into the container.
docker run mcr.microsoft.com/powershell:latest pwsh -c "&{Get-Process}"

#PowerShell Core 6.2.0, specifying a specific tag/PowerShell Core verison and platform.
docker run mcr.microsoft.com/powershell:6.2.0-ubuntu-18.04 pwsh -c "&{Get-Process}"

#PowerShell Core 6.2.0-rc.1, getting crazy and running preview. 
docker run mcr.microsoft.com/powershell:preview pwsh -c "&{Get-Host}"

#get a list of the containers on our machine, we can re-use them if needed...but why?
docker ps -a

#Let's clean them all out...carefull with this one, it will delete any container with the word powershell in the output.
docker ps -a | grep "powershell" | awk '{print $1}' | xargs docker rm

#Start up our PowerShell container to get a shell...we'll use this container to put data into our /scripts directory
docker run                      \
    --name "pwsh-script"        \
    --detach                    \
    --volume PSScripts:/scripts \
      mcr.microsoft.com/powershell:6.2.0-ubuntu-18.04 

#Our container started and stopped right away, because we detatched from the terminal.
docker ps -a

#Copy our script into the container and place it on the volume we want to store our scripts on
docker cp Get-Containers.ps1 pwsh-script:/scripts

#We can delete this container if we like, we used it just to make that copy work.
docker rm pwsh-script

docker volume ls

#Now...we can start our container with the volume and use the scripts in there.
docker run                      \
    --name "pwsh-script"        \
    --interactive --tty         \
    --volume PSScripts:/scripts \
      mcr.microsoft.com/powershell:6.2.0-ubuntu-18.04 

ls -la /scripts/
/scripts/Get-Containers.ps1
exit

#Delete our container, when we're fininshed.
docker rm pwsh-script

#If we want to do that all in one line, and delete the container when we're done
#I've also added --rm, this way our container starts up, runs the script, then shutdown and removes itself.
#Imagine using this to run your scripts independent of the underlying platform.
#Sounds like...serverless, maybe function as a serivce (FaaS)?
docker run                       \
    --rm                         \
    --volume PSScripts:/scripts  \
      mcr.microsoft.com/powershell:6.2.0-ubuntu-18.04 pwsh -F /scripts/Get-Containers.ps1

docker ps -a

#Clean up time
docker ps -a | grep "powershell" | awk '{print $1}' | xargs docker rm
docker volume rm PSScripts
