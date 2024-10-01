FROM dbatools/sqlinstance:latest

# Switch to root to perform privileged operations
USER root

# Prep
RUN set -ex; \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell-lts dotnet-sdk-8.0 && \
    mkdir -p /home/mssql/.config/powershell/PSReadLine && \
    chown -R mssql /home/mssql

# PSReadline is driving me crazy
#/home/mssql/.local/share/powershell/PSReadLine/Visual Studio Code Host_history.txt


# Copy scripts and make them executable
COPY scripts/*.ps1 /home/mssql
RUN chmod +x /home/mssql/*.ps1

# Switch to the mssql user
USER mssql