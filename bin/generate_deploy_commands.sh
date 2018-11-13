################################################################################
#
# A script to append deploy commands to the post boot command file at
# $PAYARA_HOME/scripts/post-boot-commands.asadmin file. All applications in the
# $DEPLOY_DIR (either files or folders) will be deployed.
# The $POSTBOOT_COMMANDS file can then be used with the start-domain using the
#  --postbootcommandfile parameter to deploy applications on startup.
#
# Usage:
# ./generate_deploy_commands.sh
#
# Optionally, any number of parameters of the asadmin deploy command can be 
# specified as parameters to this script. 
# E.g., to deploy applications with implicit CDI scanning disabled:
#
# ./generate_deploy_commands.sh --properties=implicitCdiEnabled=false
#
# Note that many parameters to the deploy command can be safely used only when 
# a single application exists in the $DEPLOY_DIR directory.
################################################################################

# Create pre and post boot command files if they don't exist
touch $POSTBOOT_COMMANDS
touch $PREBOOT_COMMANDS

# RAR files first
for deployment in $(find ${PAYARA_PATH}/deployments/ -maxdepth 1 -name "*.rar");
do
	echo "Adding deployment target $deployment to post boot commands";
	echo "deploy $DEPLOY_OPTS $deployment" >> $POSTBOOT_COMMANDS;
done

# Then every other WAR, EAR, JAR or directory
for deployment in $(find ${PAYARA_PATH}/deployments/ -maxdepth 1 ! -name "*.rar" -a -name "*.war" -o -name "*.ear" -o -name "*.jar" -o -type d);
do
	echo "Adding deployment target $deployment to post boot commands";
	echo "deploy $DEPLOY_OPTS $deployment" >> $POSTBOOT_COMMANDS;
done