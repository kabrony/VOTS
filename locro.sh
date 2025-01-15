#!/usr/bin/env bash

# Some ANSI color codes
RED="\033[1;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

echo -e "${BLUE}=== LOCRO DEMO SCRIPT ===${RESET}"
echo -e "This text is normal, but now we print some colored lines..."

echo -e "${RED}Error:${RESET} Something went wrong!"
echo -e "${GREEN}Success:${RESET} Task completed."
echo -e "${YELLOW}Warning:${RESET} Disk space is low."
echo -e "${CYAN}Info:${RESET} Docker images cleaned."
echo -e "${MAGENTA}Status:${RESET} Everything is up-to-date."

echo -e ""
echo -e "End of the ${BLUE}locro.sh${RESET} demo. Enjoy the colors!"

