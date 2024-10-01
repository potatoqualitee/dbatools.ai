FROM dbatools/sqlinstance:latest

# Switch to root to perform privileged operations
USER root

# Prep
RUN set -ex; \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell-lts git dotnet-sdk-8.0 && \
    mkdir -p /home/mssql/.config/powershell ; \
    chown -R mssql /home/mssql ; \
    rm -rf /opt/microsoft/powershell/7-lts/Modules/PSReadLine

# Copy scripts and make them executable
COPY scripts/*.ps1 /home/mssql
RUN chmod +x /home/mssql/*.ps1; pwsh -noprofile /home/mssql/setup.ps1

# Switch to the mssql user
USER mssql