FROM openjdk:8u171-jdk

# Default payara ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181

# Initialize the configurable environment variables
ENV PAYARA_PATH=/opt/payara\
    DOMAIN_NAME=docker-domain\
    # Credentials for Payara
    ADMIN_USER=admin\
    ADMIN_PASSWORD=admin \
    # Payara download link
    PAYARA_PKG=https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.183/payara-5.183.zip\
    # Utility environment variables
    JVM_ARGS=\
    DEPLOY_PROPS=\
    DEPLOY_DIR=/opt/payara/deployments\
    POSTBOOT_COMMANDS=/opt/payara/scripts/post-boot-commands.asadmin\
    PREBOOT_COMMANDS=/opt/payara/scripts/pre-boot-commands.asadmin\
    AS_ADMIN_PATH=/opt/payara/appserver/bin/asadmin

# Create and set the Payara user and working directory owned by the new user
RUN groupadd payara && \
    useradd -b ${PAYARA_PATH} -M -s /bin/bash -d ${PAYARA_PATH} payara -g payara && \
    mkdir -p ${DEPLOY_DIR} && \
    chown -R payara:payara ${PAYARA_PATH}
USER payara
WORKDIR ${PAYARA_PATH}

# Download and unzip the Payara distribution
RUN wget --no-verbose -O payara.zip http://central.maven.org/maven2/fish/payara/distributions/payara/5.183/payara-5.183.zip && \
    chown payara:payara payara.zip && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver && \
    # Configure the password file for configuring Payara
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> passwordFile && \
    # Create and configure a domain
    appserver/bin/asadmin --user=${ADMIN_USER} --passwordfile=passwordFile create-domain --template=appserver/glassfish/common/templates/gf/production-domain.jar ${DOMAIN_NAME} && \
    appserver/bin/asadmin --user=${ADMIN_USER} --passwordfile=passwordFile start-domain ${DOMAIN_NAME} && \
    appserver/bin/asadmin --user=${ADMIN_USER} --passwordfile=passwordFile enable-secure-admin && \
    appserver/bin/asadmin --user=${ADMIN_USER} --passwordfile=passwordFile stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf \
        payara.zip \
        appserver/glassfish/domains/${DOMAIN_NAME}/osgi-cache \
        appserver/glassfish/domains/production \
        appserver/glassfish/domains/domain1 \
        appserver/glassfish/common/templates/gf

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh scripts/
RUN chmod +x scripts/*

CMD ${PAYARA_PATH}/scripts/generate_deploy_commands.sh && ${PAYARA_PATH}/scripts/startInForeground.sh  --passwordfile=/opt/payara/passwordFile --postbootcommandfile ${POSTBOOT_COMMANDS} ${PAYARA_DOMAIN}
