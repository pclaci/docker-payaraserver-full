#!/bin/bash

${SCRIPT_DIR}/generate_deploy_commands.sh
exec ${SCRIPT_DIR}/startInForeground.sh
