# Create a database assistant
Get-DbaDatabase -SqlInstance localhost -Database Northwind | New-DbaiAssistant

# Query using natural language
Invoke-DbaiQuery Any employee birthdays in December?

# Use dbatools commands with natural language
Invoke-DbatoolsAI Simulate what would happen if I tried to copy the SalesDB database from sql01 to sql02 using the network share \\NetworkPath and backup/restore. No questions, just try it. If it fails, tell me the command you ran then give me some suggestions on how to fix it.