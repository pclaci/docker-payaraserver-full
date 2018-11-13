FROM openjdk:8u171-jdk

# Create and set the Payara user and working directory owned by the new user
RUN groupadd payara && \
    useradd -b /opt/payara/ -M -s /bin/bash -d /opt/payara/ payara -g payara && \
    mkdir -p /opt/payara/deployments/ && \
    chown -R payara:payara /opt/payara/
USER payara
WORKDIR /opt/payara/

# Define ports to expose
EXPOSE 4848 9009 8080 8181

# Initialize the configurable environment variables
ENV JVM_ARGS=\
    DEPLOY_PROPS=

# Download and unzip the Payara distribution
RUN wget --no-verbose -O payara.zip http://central.maven.org/maven2/fish/payara/distributions/payara/5.183/payara-5.183.zip && \
    chown payara:payara payara.zip && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver

# Configure the password files for configuring Payara
RUN echo '\
AS_ADMIN_PASSWORD=\n\
AS_ADMIN_NEWPASSWORD=admin\n\
EOF\n' >> /tmp/tmpFile && \
    echo '\
AS_ADMIN_PASSWORD=admin' >> /opt/payara/passwordFile

# Configure domain1
RUN appserver/bin/asadmin --user=admin --passwordfile=/tmp/tmpFile change-admin-password && \
    appserver/bin/asadmin start-domain domain1 && \
    appserver/bin/asadmin --user=admin --passwordfile=/opt/payara/passwordFile enable-secure-admin && \
    appserver/bin/asadmin stop-domain domain1 && \
    rm -rf appserver/glassfish/domains/domain1/osgi-cache && \
    rm /tmp/tmpFile

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh scripts/
RUN chmod +x scripts/*

CMD scripts/entrypoint.sh