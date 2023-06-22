FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /source

# copy csproj and restore as distinct layers
COPY v2/webapp/*.csproj ./webappv2/
WORKDIR /source/webappv2
RUN dotnet restore 

# copy everything else and build app
COPY v2/webapp/. ./webappv2/
WORKDIR /source/webappv2
RUN dotnet publish -c release -o /app --no-restore

# final stage/image
FROM mcr.microsoft.com/dotnet/aspnet:7.0
WORKDIR /app
COPY --from=build /app ./
EXPOSE 8080
ENTRYPOINT ["dotnet", "webapp.dll"]
