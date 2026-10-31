#!/bin/bash

# Define container name, username, and password for SQL Server INSIDE the container
CONTAINER_NAME="mssql-server"
USERNAME="sa"  # Replace with your SQL Server username inside the container
PASSWORD="P@ssword92"  # Replace with your SQL Server password inside the container

# Path to the SQL script file (needs to be accessible within the container,
# or we'll pass it as a command)
SQL_SCRIPT="/tmp/setup-acmedb.sql" # Assuming you'll copy it into the container

# Copy the SQL script into the container and then execute
echo "Copying SQL script to the container..."
docker cp setup-acmedb.sql "$CONTAINER_NAME:$SQL_SCRIPT"

# Construct the sqlcmd command to run inside the container
SQLCMD_COMMAND="/opt/mssql-tools18/bin/sqlcmd -S localhost -U '$USERNAME' -P '$PASSWORD' -N -C -i '$SQL_SCRIPT'"

echo "Executing SQL script inside the container..."
docker exec "$CONTAINER_NAME" bash -c "$SQLCMD_COMMAND"

# Get the exit code from the last executed command inside the container
EXIT_CODE=$?

# Check the exit code
if [ $EXIT_CODE -eq 0 ]; then
  echo "Database 'AcmeDB', schema 'Recruits', and table 'Recruits.Users' created and populated successfully inside the container."
else
  echo "An error occurred during database setup inside the container. Check the output above for details (it's from within the container)."
fi
