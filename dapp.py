from os import environ
import logging
import requests
import subprocess

logging.basicConfig(level="INFO")
logger = logging.getLogger(__name__)

rollup_server = environ["ROLLUP_HTTP_SERVER_URL"]
logger.info(f"HTTP rollup_server url is {rollup_server}")

LLAMA_CPP_PATH = "/llama.cpp/build/bin/main"
MODEL_PATH = "/models/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/"

def call_llama(prompt):
    try:
        command = [
            LLAMA_CPP_PATH,
            "-m", MODEL_PATH,
            "-p", prompt,
        ]
        result = subprocess.run(command, capture_output=True, text=True)

        return result.stdout.strip()

    except Exception as e:
        logger.error(f"Error calling llama.cpp: {e}")
        return None

def handle_advance(data):
    logger.info(f"Received advance request data {data}")

    try:
        payload = data["payload"]
        logger.info(f"Input payload: {payload}")

        response = call_llama(payload)

        if response:
            logger.info(f"DeepSeek says: {response}")

        else:
            logger.error("Failed to generate a response.")

    except Exception as e:
        logger.error(f"Error handling advance request: {e}")

    return "accept"


def handle_inspect(data):
    logger.info(f"Received inspect request data {data}")
    return "accept"


handlers = {
    "advance_state": handle_advance,
    "inspect_state": handle_inspect,
}

finish = {"status": "accept"}

while True:
    logger.info("Sending finish")
    response = requests.post(rollup_server + "/finish", json=finish)
    logger.info(f"Received finish status {response.status_code}")
    if response.status_code == 202:
        logger.info("No pending rollup request, trying again")
    else:
        rollup_request = response.json()
        data = rollup_request["data"]
        handler = handlers[rollup_request["request_type"]]
        finish["status"] = handler(rollup_request["data"])
