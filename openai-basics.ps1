# **Connecting to the OpenAI API using PowerShell**

Using the OpenAI API in PowerShell requires an API key from https://platform.openai.com/api-keys.

### Using PSOpenAI to connect to OpenAI

# Straightforward request
Request-ChatCompletion -Message "What is a splat?" | Select-Object -ExpandProperty Answer

# Note the developer manually keeping track of the conversation history
Request-ChatCompletion -Message "What is a splat?"

### Raw PowerShell behind the scenes
# Set the headers
$headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $env:OPENAI_API_KEY"
}

# Prepare the messages array
$msgs = @(
    @{
        role    = "user"
        content = "What is a splat?"
    }
)

# Create the splat for Invoke-RestMethod
$splat = @{
    Uri     = "https://api.openai.com/v1/chat/completions"
    Method  = "Post"
    Headers = $headers
    Body    = @{
        model    = "gpt-4o"
        messages = $msgs
    } | ConvertTo-Json
}

$response = Invoke-RestMethod @splat

# Output the assistant's reply
$response.choices[0].message.content

# No history of the conversation by default
$response

# Let's set some default values
# Set default values
$PSDefaultParameterValues["Invoke-RestMethod:Headers"] = $headers
$PSDefaultParameterValues["Invoke-RestMethod:Method"] = "POST"
$PSDefaultParameterValues["Invoke-RestMethod:Uri"] = "https://api.openai.com/v1/chat/completions"
$PSDefaultParameterValues["*:OutVariable"] = "outvar"