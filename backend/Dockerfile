FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source
COPY . .
RUN dotnet restore src/CampusConnect.Api/CampusConnect.Api.csproj --locked-mode
RUN dotnet publish src/CampusConnect.Api/CampusConnect.Api.csproj -c Release --no-restore -o /app
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:4000
EXPOSE 4000
USER $APP_UID
ENTRYPOINT ["dotnet", "CampusConnect.Api.dll"]
