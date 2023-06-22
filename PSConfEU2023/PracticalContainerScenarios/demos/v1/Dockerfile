FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /source

# copy csproj and restore as distinct layers
COPY v1/webapp/*.csproj ./webappv1/
WORKDIR /source/webappv1
RUN dotnet restore 

# copy everything else and build app
COPY v1/webapp/. ./webappv1/
WORKDIR /source/webappv1
RUN dotnet publish -c release -o /app --no-restore

# final stage/image
FROM mcr.microsoft.com/dotnet/aspnet:7.0
WORKDIR /app
COPY --from=build /app ./
EXPOSE 8080
ENTRYPOINT ["dotnet", "webapp.dll"]
