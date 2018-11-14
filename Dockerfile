FROM openjdk:8u171-jdk

# Default payara ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181

# Initialize the configurable environment variables
ENV HOME_DIR=/opt/payara\
    PAYARA_DIR=/opt/payara/appserver\
    SCRIPT_DIR=/opt/payara/scripts\
    CONFIG_DIR=/opt/payara/config\
    DEPLOY_DIR=/opt/payara/deployments\
    PASSWORD_FILE=/opt/payara/passwordFile\
    # Payara version
    PAYARA_VERSION=5.183\
    # Payara Server Domain options
    DOMAIN_NAME=docker-domain\
    ADMIN_USER=admin\
    ADMIN_PASSWORD=admin \
    # Utility environment variables
    JVM_ARGS=\
    DEPLOY_PROPS=\
    POSTBOOT_COMMANDS=/opt/payara/config/post-boot-commands.asadmin\
    PREBOOT_COMMANDS=/opt/payara/config/pre-boot-commands.asadmin

# Create and set the Payara user and working directory owned by the new user
RUN groupadd payara && \
    useradd -b ${HOME_DIR} -M -s /bin/bash -d ${HOME_DIR} payara -g payara && \
    mkdir -p ${DEPLOY_DIR} && \
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${SCRIPT_DIR} && \
    chown -R payara:payara ${HOME_DIR}
USER payara
WORKDIR ${HOME_DIR}

# Download and unzip the Payara distribution
RUN wget --no-verbose -O payara.zip http://central.maven.org/maven2/fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip && \
    chown payara:payara payara.zip && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver && \
    # Configure the password file for configuring Payara
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> ${PASSWORD_FILE} && \
    # Create and configure a domain
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} create-domain --template=${PAYARA_DIR}/glassfish/common/templates/gf/production-domain.jar ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} start-domain ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} enable-secure-admin && \
    for MEMORY_JVM_OPTION in $(${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} list-jvm-options | grep "Xm[sx]"); do\
        ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} delete-jvm-options $MEMORY_JVM_OPTION;\
    done && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} create-jvm-options '-XX\:+UnlockExperimentalVMOptions:-XX\:+UseCGroupMemoryLimitForHeap' && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.logtoFile=false && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf \
        payara.zip \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/osgi-cache \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/logs \
        ${PAYARA_DIR}/glassfish/domains/production \
        ${PAYARA_DIR}/glassfish/domains/domain1 \
        ${PAYARA_DIR}/glassfish/common/templates/gf

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh ${SCRIPT_DIR}/
RUN chmod +x ${SCRIPT_DIR}/*

CMD ${SCRIPT_DIR}/generate_deploy_commands.sh && ${SCRIPT_DIR}/startInForeground.sh