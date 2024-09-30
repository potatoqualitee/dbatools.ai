FROM dbatools/sqlinstance:latest

# Switch to root to perform privileged operations
USER root

# Expose the SQL Server port
EXPOSE 1433

# Install PowerShell
RUN set -ex; \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell-lts dotnet-sdk-8.0

# Create the home directory for the mssql user and set the correct permissions
RUN mkdir -p /home/mssql && \
    chown -R mssql /home/mssql

# convert CRLF to LF in case Windows or VS Code changed it
RUN find /opt/mssql/bin/ -type f \( -name "*.sql" -o -name "*.env" -o -name "*.sh" \) -exec sed -i 's/\r$//' {} \;

# Copy scripts and make them executable
COPY scripts/*.ps1 /tmp/
RUN chmod +x /tmp/*.ps1

# Switch to the mssql user
USER mssql

# Set the entrypoint
# ENTRYPOINT /opt/mssql/bin/sqlservr & /opt/mssql/bin/post-entrypoint.sh
# Run SQL Server process
CMD /opt/mssql/bin/sqlservr