FROM mcr.microsoft.com/mssql/server

# Switch to root to perform privileged operations
USER root

# Install necessary packages and clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    powershell-lts \
    git \
    dotnet-sdk-9.0 \
    python3-pip \
    poppler-utils \
    curl \
    universal-ctags \
    wget && \
    rm -rf /var/lib/apt/lists/*

# Install aider-chat
RUN python3 -m pip install --no-cache-dir aider-chat

# Install ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Prepare directories, copy scripts, set permissions, and change ownership
RUN mkdir -p /home/mssql/.config/powershell && \
    chown -R mssql /home/mssql

COPY ./scripts/*.ps1 /home/mssql/

# Copy profile.ps1 to various profile locations
RUN cp /home/mssql/profile.ps1 /home/mssql/.config/powershell/Microsoft.PowerShell_profile.ps1 && \
    cp /home/mssql/profile.ps1 /home/mssql/.config/powershell/Microsoft.dotnet-interactive_profile.ps1 && \
    cp /home/mssql/profile.ps1 /home/mssql/.config/powershell/Microsoft.VSCode_profile.ps1 && \
    chmod +x /home/mssql/*.ps1 && \
    chown -R mssql /home/mssql

# Switch to the mssql user
USER mssql
