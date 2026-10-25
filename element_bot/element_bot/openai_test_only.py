import os
import logging
import sys
import time
from openai import OpenAI  # Changed to synchronous client for simplicity

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Get OpenRouter API key from environment
api_key = os.environ.get("OPENROUTER_API_KEY")
if not api_key:
    raise EnvironmentError("Missing required environment variable: OPENROUTER_API_KEY")

# OpenRouter speaks the OpenAI API
client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=api_key)

# Pass a model ID as the first argument to test a specific model
MODEL = sys.argv[1] if len(sys.argv) > 1 else "google/gemma-4-31b-it:free"

# System prompt
SYSTEM_PROMPT = """
You are a helpful and friendly assistant in a Matrix chat room.
Be concise, informative, and engaging in your responses.
"""

def test_openai_call(message="Hi there, can you help me?"):
    """Simple function to test an OpenRouter API call"""
    logger.info("Starting OpenRouter API test")
    
    try:
        # Add a small delay before making the call
        time.sleep(1)
        
        # Make the API call
        logger.info(f"Sending request to {MODEL} with message: {message}")
        start_time = time.time()
        
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": message}
            ]
        )
        
        elapsed_time = time.time() - start_time
        logger.info(f"API call completed in {elapsed_time:.2f} seconds")
        
        # Extract and return the response content
        content = response.choices[0].message.content
        logger.info(f"Response received: {content[:50]}...")
        return content
        
    except Exception as e:
        logger.error(f"Error calling OpenRouter API: {str(e)}")
        return f"Error: {str(e)}"

if __name__ == "__main__":
    user_message = "Hi my friend convert 'set timer for ten minutes 3 seconds' into python code to wait for that period"
    result = test_openai_call(user_message)
    print("\n--- RESULT ---\n")
    print(result)
    print("\n--------------")