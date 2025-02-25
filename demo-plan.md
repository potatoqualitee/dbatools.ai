# Demo Time Conversion Plan

## Overview
Convert demo-output.ipynb Jupyter notebook into a Demo Time demo configuration that walks through PowerShell OpenAI integration and dbatools.ai functionality.

## Structure

### 1. Initial Setup
- Create `.demo` folder
- Create main demo configuration file with schema reference
- Set up variables.json for any reusable values

### 2. Demo Sections

#### Section 1: Wrappers vs Integrations
- Create file to display comparison table
- Add highlight steps to emphasize key points
- Show benefits list

#### Section 2: OpenAI API Basics
- Create PowerShell files for API examples
- Demo steps to:
  - Show basic API connection
  - Display raw PowerShell implementation
  - Set default parameters
  - Show model listing

#### Section 3: Assistants
- Demo creating and using assistants
- Show conversation threads
- Demonstrate file attachments
- Include image comparison example

#### Section 4: dbatools.ai Features
- Import-DbaiFile demonstration
- Structured output examples
- Database querying
- Natural language processing

### 3. Implementation Details

#### File Structure
```
.demo/
  ├── demo.json           # Main demo configuration
  ├── variables.json      # Shared variables
  ├── snippets/          # Reusable code snippets
  └── content/           # Demo content files
```

#### Demo Steps Types
1. File creation/modification
2. Code highlighting
3. Command execution
4. Terminal output display
5. Image viewing

### 4. Special Considerations
- Need to handle PowerShell output formatting
- Ensure proper timing between steps
- Add descriptive notes for each major section
- Include proper error handling for commands

## Next Steps
1. Create the basic folder structure
2. Convert each notebook section into demo steps
3. Test each section independently
4. Combine into final demo configuration
5. Add presenter notes

Would you like me to proceed with implementing this plan? We can switch to code mode to create the demo configuration and files.