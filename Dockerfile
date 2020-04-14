FROM adoptopenjdk/openjdk11-openj9

# Default payara ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181

# Payara version (5.183+)
ARG PAYARA_VERSION=5.193.1
ARG PAYARA_PKG=https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip
ARG PAYARA_SHA1=b01e7621b1b31185fdf32892a1bd76aa72e990f4
ARG TINI_VERSION=v0.18.0

# Initialize the configurable environment variables
ENV HOME_DIR=/opt/payara\
    PAYARA_DIR=/opt/payara/appserver\
    SCRIPT_DIR=/opt/payara/scripts\
    CONFIG_DIR=/opt/payara/config\
    DEPLOY_DIR=/opt/payara/deployments\
    PASSWORD_FILE=/opt/payara/passwordFile\
    # Payara Server Domain options
    DOMAIN_NAME=production\
    ADMIN_USER=admin\
    ADMIN_PASSWORD=admin \
    # Utility environment variables
    JVM_ARGS=\
    PAYARA_ARGS=\
    DEPLOY_PROPS=\
    POSTBOOT_COMMANDS=/opt/payara/config/post-boot-commands.asadmin\
    PREBOOT_COMMANDS=/opt/payara/config/pre-boot-commands.asadmin
ENV PATH="${PATH}:${PAYARA_DIR}/bin"

# Create and set the Payara user and working directory owned by the new user
RUN groupadd -g 1000 payara && \
    useradd -u 1000 -M -s /bin/bash -d ${HOME_DIR} payara -g payara && \
    echo payara:payara | chpasswd && \
    mkdir -p ${DEPLOY_DIR} && \
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${SCRIPT_DIR} && \
    chown -R payara: ${HOME_DIR} && \
    # Install required packages
    apt-get update && \
    apt-get install -y wget unzip gnupg && \
    rm -rf /var/lib/apt/lists/*

# Install tini as minimized init system
RUN wget --no-verbose -O /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini && \
    wget --no-verbose -O /tini.asc https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc && \
    gpg --batch --keyserver "hkp://p80.pool.sks-keyservers.net:80" --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && \
    gpg --batch --verify /tini.asc /tini && \
    chmod +x /tini

USER payara
WORKDIR ${HOME_DIR}

# Download and unzip the Payara distribution
RUN wget --no-verbose -O payara.zip ${PAYARA_PKG} && \
    echo "${PAYARA_SHA1} *payara.zip" | sha1sum -c - && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver && \
    # Configure the password file for configuring Payara
    echo "AS_ADMIN_PASSWORD=\nAS_ADMIN_NEWPASSWORD=${ADMIN_PASSWORD}" > /tmp/tmpfile && \
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> ${PASSWORD_FILE} && \
    # Configure the payara domain
    ${PAYARA_DIR}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/tmp/tmpfile change-admin-password --domain_name=${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} start-domain ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} enable-secure-admin && \
    for MEMORY_JVM_OPTION in $(${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} list-jvm-options | grep "Xm[sx]"); do\
        ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} delete-jvm-options $MEMORY_JVM_OPTION;\
    done && \
    # FIXME: when upgrading this container to Java 10+, this needs to be changed to '-XX:+UseContainerSupport' and '-XX:MaxRAMPercentage'
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} create-jvm-options '-XX\:+UnlockExperimentalVMOptions:-XX\:+UseCGroupMemoryLimitForHeap:-XX\:MaxRAMFraction=1' && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.logtoFile=false && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} delete-jvm-options --profiler=false --target=server-config '-Djavax.net.ssl.keyStore=${com.sun.aas.instanceRoot}/config/keystore.jks:-XX\:+UseG1GC:-Xbootclasspath/p\:${com.sun.aas.installRoot}/lib/grizzly-npn-bootstrap-1.7.jar:-XX\:+UnlockExperimentalVMOptions:-XX\:+UseCGroupMemoryLimitForHeap:-DANTLR_USE_DIRECT_CLASS_LOADING=true:-Xbootclasspath/p\:${com.sun.aas.installRoot}/lib/grizzly-npn-bootstrap-1.6.jar:-Dorg.jboss.weld.serialization.beanIdentifierIndexOptimization=false:-Djavax.net.ssl.trustStore=${com.sun.aas.instanceRoot}/config/cacerts.jks:-XX\:+UseStringDeduplication:-Dorg.glassfish.grizzly.nio.DefaultSelectorHandler.force-selector-spin-detection=true:-XX\:MaxGCPauseMillis=500:-Djdk.tls.rejectClientInitiatedRenegotiation=true:-XX\:+UnlockDiagnosticVMOptions:-Djava.security.auth.login.config=${com.sun.aas.instanceRoot}/config/login.conf:-Djava.awt.headless=true:-Xbootclasspath/p\:${com.sun.aas.installRoot}/lib/grizzly-npn-bootstrap-1.8.jar:-Djdbc.drivers=org.apache.derby.jdbc.ClientDriver:-Xbootclasspath/p\:${com.sun.aas.installRoot}/lib/grizzly-npn-bootstrap-1.8.1.jar:-Djava.ext.dirs=${com.sun.aas.javaRoot}/lib/ext${path.separator}${com.sun.aas.javaRoot}/jre/lib/ext${path.separator}${com.sun.aas.instanceRoot}/lib/ext:-Djdk.corba.allowOutputStreamSubclass=true:-XX\:MaxRAMFraction=1:-Dorg.glassfish.grizzly.DEFAULT_MEMORY_MANAGER=org.glassfish.grizzly.memory.HeapMemoryManager:-Djavax.xml.accessExternalSchema=all:-XX\:MetaspaceSize=256m:-Djava.security.policy=${com.sun.aas.instanceRoot}/config/server.policy:--add-exports=java.base/jdk.internal.ref=ALL-UNNAMED:-Xbootclasspath/a\:${com.sun.aas.installRoot}/lib/grizzly-npn-api.jar:-Djava.endorsed.dirs=${com.sun.aas.installRoot}/modules/endorsed${path.separator}${com.sun.aas.installRoot}/lib/endorsed:-Dcom.sun.enterprise.config.config_environment_factory_class=com.sun.enterprise.config.serverbeans.AppserverConfigEnvironmentFactory:--add-opens=java.base/sun.net.www.protocol.jrt=ALL-UNNAMED:-XX\:MaxMetaspaceSize=2g' && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} create-jvm-options --profiler=false --target=server-config '-Djdk.corba.allowOutputStreamSubclass=true:-XX\:+UseG1GC:-Djdk.tls.rejectClientInitiatedRenegotiation=true:-Dcom.sun.enterprise.config.config_environment_factory_class=com.sun.enterprise.config.serverbeans.AppserverConfigEnvironmentFactory:[9|]-Xbootclasspath\/a\:$\{com.sun.aas.installRoot\}\/lib\/grizzly-npn-api.jar:-XX\:+UnlockExperimentalVMOptions:-Djava.security.auth.login.config=$\{com.sun.aas.instanceRoot\}\/config\/login.conf:-XX\:+UseCGroupMemoryLimitForHeap:-Djava.security.policy=$\{com.sun.aas.instanceRoot\}\/config\/server.policy:-Xtune\:virtualized:-Dorg.glassfish.grizzly.DEFAULT_MEMORY_MANAGER=org.glassfish.grizzly.memory.HeapMemoryManager:-Djavax.xml.accessExternalSchema=all:-XX\:MaxRAMFraction=1:[1.8.0.121|1.8.0.160]-Xbootclasspath\/p\:$\{com.sun.aas.installRoot\}\/lib\/grizzly-npn-bootstrap-1.7.jar:[9|]--add-opens=java.base\/sun.net.www.protocol.jrt\=ALL-UNNAMED:-XX\:MetaspaceSize=256m:-Djava.awt.headless=true:-XX\:+UseStringDeduplication:[|8]-Djava.endorsed.dirs=$\{com.sun.aas.installRoot\}\/modules\/endorsed$\{path.separator\}$\{com.sun.aas.installRoot\}\/lib\/endorsed:-Djdbc.drivers=org.apache.derby.jdbc.ClientDriver:-XX\:+UnlockDiagnosticVMOptions:[1.8.0|1.8.0.120]-Xbootclasspath\/p\:$\{com.sun.aas.installRoot\}\/lib\/grizzly-npn-bootstrap-1.6.jar:[1.8.0.161|1.8.0.190]-Xbootclasspath\/p\:$\{com.sun.aas.installRoot\}\/lib\/grizzly-npn-bootstrap-1.8.jar:[1.8.0.191|1.8.0.500]-Xbootclasspath\/p\:$\{com.sun.aas.installRoot\}\/lib\/grizzly-npn-bootstrap-1.8.1.jar:-Djavax.net.ssl.keyStore=$\{com.sun.aas.instanceRoot\}\/config\/keystore.jks:-DANTLR_USE_DIRECT_CLASS_LOADING=true:-Dorg.glassfish.grizzly.nio.DefaultSelectorHandler.force-selector-spin-detection=true:-Xquickstart:-XX\:MaxGCPauseMillis=500:-Djavax.net.ssl.trustStore=$\{com.sun.aas.instanceRoot\}\/config\/cacerts.jks:-Dorg.jboss.weld.serialization.beanIdentifierIndexOptimization=false:[9|]--add-exports=java.base\/jdk.internal.ref\=ALL-UNNAMED:[|8]-Djava.ext.dirs=$\{com.sun.aas.javaRoot\}\/lib\/ext$\{path.separator\}$\{com.sun.aas.javaRoot\}\/jre\/lib\/ext$\{path.separator\}$\{com.sun.aas.instanceRoot\}\/lib\/ext:-XX\:MaxMetaspaceSize=2g' && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf \
        /tmp/tmpFile \
        payara.zip \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/osgi-cache \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/logs \
        ${PAYARA_DIR}/glassfish/domains/domain1

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh ${SCRIPT_DIR}/
RUN mkdir -p ${SCRIPT_DIR}/init.d && \
    chmod +x ${SCRIPT_DIR}/*

ENTRYPOINT ["/tini", "--"]
CMD ["scripts/entrypoint.sh"]
