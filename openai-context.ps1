### But what about PowerShell Splats? Let's narrow the response context
# Prepare the messages array
$msgs = @(
    @{
        role    = "system"
        content = "You are a PowerShell Expert."
    }
    @{
        role    = "user"
        content = "What is a splat?"
    }
)

# Prepare the body
$body = @{
    model    = "gpt-4o"
    messages = $msgs
} | ConvertTo-Json

$response = Invoke-RestMethod -Body $body

# Output the assistant's reply
$response.choices[0].message.content

### Btw, how do I know which models I can use?
(Invoke-RestMethod -Method Get -Uri https://api.openai.com/v1/models).data.id