FROM mcr.microsoft.com/dotnet/core/aspnet:2.2
COPY ./myWebApp/bin/Release/netcoreapp2.2/publish app/
ENTRYPOINT ["dotnet", "app/myWebApp.dll"]
EXPOSE 80