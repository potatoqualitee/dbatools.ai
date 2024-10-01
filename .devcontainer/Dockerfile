FROM dbatools/sqlinstance:latest

# Switch to root to perform privileged operations
USER root

# Copy scripts and make them executable
COPY scripts/*.ps1 /home/mssql
RUN chmod +x /home/mssql/*.ps1
RUN mkdir -p /home/mssql/.config/powershell
RUN mv /home/mssql/Microsoft.PowerShell_profile.ps1 /home/mssql/.config/powershell
RUN chown -R mssql /home/mssql

# PSReadLine bites it in codespaces
RUN rm -rf /opt/microsoft/powershell/7-lts/Modules/PSReadLine

# Prep
RUN apt-get install -y --no-install-recommends powershell-lts git dotnet-sdk-8.0

# setup as root
RUN pwsh -noprofile /tmp/setup.ps1

# Switch to the mssql user
USER mssql