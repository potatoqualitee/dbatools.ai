# dbatools.ai overview

This module creates copilots for SQL Server databases and dbatools commands. Oh, and imports files into databases.

### **Import-DbaiFile**
Imports structured file content into a database, using AI and predefined schemas for processing.

| Step                  | Description                                                                                              |
|-----------------------|----------------------------------------------------------------------------------------------------------|
| **Input Handling**    | Accepts file paths and predefined JSON schemas for processing.                                           |
| **Schema Parsing**    | Uses the schema to validate and convert file content into structured data.                               |
| **Data Import**       | Converts the file content into database commands and imports it into the specified database. |

### **New-DbaiAssistant**
Creates an AI assistant to interpret natural language commands for database tasks.

| Step                 | Description                                                                                              |
|----------------------|----------------------------------------------------------------------------------------------------------|
| **Initialization**   | Creates an AI assistant with a specified name and instructions.                                          |
| **Configuration**    | Sets context and schema to interpret future queries.                                                     |
| **Caching**          | Caches the assistant for reuse in future commands.                                                       |

### **Invoke-DbaiQuery**
Converts natural language into SQL queries, referencing the database schema for accuracy.

| Step                    | Description                                                                                             |
|-------------------------|---------------------------------------------------------------------------------------------------------|
| **Input Handling**      | Accepts a natural language query related to database operations.                                        |
| **AI Processing**       | Uses an AI assistant to interpret input and generate an SQL (T-SQL) query.                              |
| **Schema Consultation** | References database schema (tables, columns) for constructing the query accurately.                     |

### **Invoke-DbatoolsAI**
Translates natural language input into `dbatools` commands, focusing on operations like `Copy-DbaDatabase`.

| Step                   | Description                                                                                              |
|------------------------|----------------------------------------------------------------------------------------------------------|
| **Assistant Setup**    | Checks for an existing assistant or creates one using cached instructions.                              |
| **Message Processing** | Processes natural language input and sends it to the assistant for interpretation.                      |
| **Command Execution**  | Converts input into a `dbatools` command.                                                               |