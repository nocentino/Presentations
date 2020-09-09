FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
COPY ./myWebApp/bin/Release/netcoreapp3.1/publish app/
ENTRYPOINT ["dotnet", "app/myWebApp.dll"]
EXPOSE 80