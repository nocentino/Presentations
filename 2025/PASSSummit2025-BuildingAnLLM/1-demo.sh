#!/bin/bash
############################################################################################################
# 1. Install and Start Single Ollama Instance
#    This script installs Ollama, starts the service, and demonstrates basic interactions with the Ollama CLI.
############################################################################################################
# Install Ollama using Homebrew
# Alternatively, you can use the official installation script:
# Linux - curl -fsSL https://ollama.com/install.sh | sh
# Windows - https://ollama.com/download/windows
brew install ollama


############################################################################################################
# Start the Ollama service
############################################################################################################

# Start the Ollama service in the background
ollama serve &

############################################################################################################
# Interacting with Ollama at the command line
############################################################################################################

# Run the llama3.1 model interactively with no input
ollama run llama3.1


# Run the llama3.1 model interactively with a prompt
"Who invented the relational database model and why?"


# Exit the interactive session
/bye


# Check the status of the Ollama service
# This command shows the running models and their statuses
ollama ps


# List all available models on this instance of Ollama
ollama list


############################################################################################################
# Pulling models
############################################################################################################

# Pull the llama3.1 model (if not already pulled)
ollama pull llama3.1


# Pull other models as needed
ollama pull llama3
ollama pull nomic-embed-text


############################################################################################################
# Viewing model details
############################################################################################################

# Show details of specific models
ollama show llama3.1
ollama show nomic-embed-text


# Explanation of model details:
# architecture: 
#     The type of model architecture being used (e.g., llama, bert, etc.).
#     This defines the structure of the neural network and how it processes data.
#
# parameters: 
#     The number of trainable parameters in the model (e.g., 8.0B means 8 billion parameters).
#     Larger models typically have more capacity to learn and generate complex outputs but require more resources.
#
# context length: 
#     The maximum number of tokens (words, subwords, or characters) the model can process in a single input.
#     For example, 131072 means the model can handle up to 131,072 tokens in one request.
#
# embedding length: 
#     The size of the vector representation for each token or input.
#     For example, 4096 means each token is represented as a 4,096-dimensional vector.
#
# quantization: 
#     The method used to reduce the size of the model for faster inference and lower memory usage.
#     For example, Q4_K_M refers to a specific quantization technique that reduces precision while maintaining accuracy.

############################################################################################################
# Testing a private model with a JSON payload using curl
############################################################################################################

# Send a request to the Ollama API to generate a response
curl http://localhost:11434/api/generate \
     -H "Content-Type: application/json" \
     -d '{ 
           "model":  "llama3.1", 
           "prompt": "Who invented the relational database model and why?" 
          }'

# Explanation of the response fields:
# response: 
#     Contains the full response if streaming is disabled. If streaming is enabled, this will be empty.
#
# context: 
#     An encoding of the conversation used in this response. This can be sent in the next request to maintain conversational memory.
#
# total_duration: 
#     Total time spent generating the response.
#
# load_duration: 
#     Time spent (in nanoseconds) loading the model.
#
# prompt_eval_count: 
#     Number of tokens in the input prompt.
#
# prompt_eval_duration: 
#     Time spent (in nanoseconds) evaluating the input prompt.
#
# eval_count: 
#     Number of tokens in the generated response.
#
# eval_duration: 
#     Time spent (in nanoseconds) generating the response.

############################################################################################################
# Notes:
# - Ensure the Ollama service is running before executing any commands.
# - Monitor GPU, disk, and memory usage to verify that the model is using the correct hardware resources.
# - For Apple Silicon devices, check for the following in the server logs:
#   ggml_metal_init: found device: Apple M4
############################################################################################################

code 2-demo.ps1