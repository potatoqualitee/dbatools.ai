FROM mcr.microsoft.com/mssql/server

# Switch to root to perform privileged operations
USER root

# Prep
RUN apt-get update && apt-get install -y --no-install-recommends powershell-lts git dotnet-sdk-8.0

# Copy scripts and make them executable
RUN mkdir -p /home/mssql/.config/powershell
COPY scripts/*.ps1 /home/mssql
RUN chmod +x /home/mssql/*.ps1
RUN mv /home/mssql/Microsoft.PowerShell_profile.ps1 /home/mssql/.config/powershell/Microsoft.PowerShell_profile.ps1

# Switch to the mssql user
RUN chown -R mssql /home/mssql
USER mssql