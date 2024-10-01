FROM dbatools/sqlinstance:latest

# Switch to root to perform privileged operations
USER root

# Prep
RUN set -ex; \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell-lts dotnet-sdk-8.0 && \
    mkdir -p /home/mssql/.config/powershell && \
    chown -R mssql /home/mssql

# convert CRLF to LF in case Windows or VS Code changed it
# RUN find /opt/mssql/bin/ -type f \( -name "*.sql" -o -name "*.env" -o -name "*.sh" \) -exec sed -i 's/\r$//' {} \;

# Copy scripts and make them executable
COPY scripts/*.ps1 /tmp/
RUN chmod +x /tmp/*.ps1

# Switch to the mssql user
USER mssql