#!/usr/bin/pwsh
############################################################################################################
# 2. Basic API Testing
#    Using Invoke-RestMethod to interact with a chat model API
############################################################################################################
$body = @{
    model = "llama3.1"
    prompt = "Who invented the relational database model and why?"
} | ConvertTo-Json -Depth 10 -Compress

# Send the POST request and save the response to a variable
$response_initial = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -ContentType "application/json" -Body $body


# Output the response
Write-Output "Initial Response:" $response_initial


# Use Get-Member to examine the structure of the response
$response_initial | Get-Member

############################################################################################################


############################################################################################################
# Using HttpWebRequest for more control over the HTTP request
############################################################################################################

# Create the HTTP request
$httpRequest = [System.Net.HttpWebRequest]::Create("http://localhost:11434/api/generate")
$httpRequest.Method = "POST"
$httpRequest.ContentType = "application/json"
$httpRequest.Headers.Add("Accept", "application/json")


# Write the body to the request stream
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$httpRequest.ContentLength = $bodyBytes.Length
$requestStream = $httpRequest.GetRequestStream()
$requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
$requestStream.Close()


# Get the response and handle streaming
$responseStream = $httpRequest.GetResponse().GetResponseStream()
$streamReader = New-Object System.IO.StreamReader($responseStream)


# Read the response line by line (streaming)
Write-Output "Streaming Response:"
while ($null -ne ($line = $streamReader.ReadLine())) {
    Write-Output $line
}

# Clean up resources
$streamReader.Close()
$responseStream.Close()
############################################################################################################


############################################################################################################
# Disabling streaming and processing the full response
############################################################################################################

# Prepare the request body with streaming disabled
$body = @{
    model = "llama3.1"
    prompt = "Who invented the relational database model and why?"
    stream = $false
} | ConvertTo-Json -Depth 10 -Compress

# Send the POST request
$response_initial_streaming = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -ContentType "application/json" -Body $body


# Output the full response
Write-Output "Full Response (Streaming Disabled):" $response_initial_streaming


# Examine the response structure
$response_initial_streaming | Get-Member
$response_initial_streaming.response
############################################################################################################



############################################################################################################
# Chat API with conversation history
############################################################################################################
# system    - Sets the behavior or personality of the assistant. 
#             This is like giving it background instructions or defining its tone and purpose.
# user      - Represents messages from the person interacting with the model.
# assistant – Represents the model’s responses.

# Initialize the conversation history
$conversationHistory = @(
    @{
        role    = "system"
        content = "You are a travel assistant who helps users plan trips."
    },
    @{
        role    = "user"
        content = "I want to plan a trip to Italy for 6 days in the summer. Can you help me?"
    }
)

# First call: Send the initial conversation history
$body_part1 = @{
    model = "llama3.1"
    messages = $conversationHistory
    stream = $false
} | ConvertTo-Json -Depth 10 -Compress


$response_part1 = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" -Method Post -ContentType "application/json" -Body $body_part1


# Output the response from the first call
Write-Output "Response from First Call:" $response_part1


# Add the assistant's response and the next user input to the conversation history
$conversationHistory += @(
    @{
        role    = "assistant"
        content = $response_part1.message.content
    },
    @{
        role    = "user"
        content = "I’m planning to go in June, and I’d like to visit museums and try local food, and we love wine, so we must go to a salumaria in Rome."
    }
)


# Second call: Continue the conversation
$body_part2 = @{
    model = "llama3.1"
    messages = $conversationHistory
    stream = $false
} | ConvertTo-Json -Depth 10 -Compress


$response_part2 = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" -Method Post -ContentType "application/json" -Body $body_part2


# Output the response from the second call
Write-Output "Response from Second Call:" $response_part2


# Add the assistant's response and the next user input to the conversation history
$conversationHistory += @(
    @{
        role    = "assistant"
        content = $response_part2.message.content
    },
    @{
        role    = "user"
        content = "Can you skip Tuscany and add Montepertuso, and then output a day-by-day itinerary in a table form by date and city?"
    }
)


# Third call: Continue the conversation
$body_part3 = @{
    model = "llama3.1"
    messages = $conversationHistory
    stream = $false
} | ConvertTo-Json -Depth 10 -Compress


$response_part3 = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" -Method Post -ContentType "application/json" -Body $body_part3


# Output the response from the third call
Write-Output "Response from Third Call:" $response_part3


# Add the assistant's response and the next user input to the conversation history
$conversationHistory += @(
    @{
        role    = "assistant"
        content = $response_part3.message.content
    },
    @{
        role    = "user"
        content = "Mamma Mia, I forgot to tell you that you're Super Mario. Can you give me the itinerary again per favore?"
    }
)


# Fourth call: Continue the conversation, but as Super Mario
$body_part4 = @{
    model = "llama3.1"
    messages = $conversationHistory
    stream = $false
} | ConvertTo-Json -Depth 10 -Compress


$response_part4 = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" -Method Post -ContentType "application/json" -Body $body_part4


# Output the response from the fourth call
Write-Output "Response from Fourth Call:" $response_part4

############################################################################################################
# conversationHistory holds the entire conversation history/chat over time you'll want to truncate
# the conversation history or summarize it. You can also persist it to a database or file.
# - Staying under the model's context limit (e.g., 4k, 8k, or 32k tokens),
# - Keeping the most relevant parts of the chat,
# - Improving performance and reducing unnecessary load.


############################################################################################################
# Output the entire conversation history
############################################################################################################
Write-Output "Full Conversation History:"
$conversationHistory

code ./3-demo.sh