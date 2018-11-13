FROM openjdk:8u171-jdk

ENV ADMIN_USER=admin \
# set credentials to admin/admin
    ADMIN_PASSWORD=admin \
    PAYARA_PATH=/opt/payara5 \
# specify Payara version to download
    PAYARA_PKG=https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/5.183/payara-5.183.zip \
    PAYARA_VERSION=5.183

COPY generate_deploy_commands.sh ${PAYARA_PATH}/generate_deploy_commands.sh
COPY bin/startInForeground.sh ${PAYARA_PATH}/bin/startInForeground.sh

RUN \
 mkdir -p ${PAYARA_PATH}/deployments && \
# add payara user
 useradd --home-dir ${PAYARA_PATH} -s /bin/bash -d ${PAYARA_PATH} payara && \
 echo payara:payara | chpasswd && \
 chmod a+x ${PAYARA_PATH}/generate_deploy_commands.sh && \
 chmod a+x ${PAYARA_PATH}/bin/startInForeground.sh && \
# download Payara Server, install, then remove downloaded file
 wget --no-verbose -O /opt/payara-full.zip ${PAYARA_PKG} && \
 unzip -qq /opt/payara-full.zip -d /opt && \
 chown -R payara:payara /opt && \
 ln -s ${PAYARA_PATH} /opt/payara && \
 rm /opt/payara-full.zip

USER payara
WORKDIR ${PAYARA_PATH}

# set credentials to admin/admin for both domains
RUN \
 echo "AS_ADMIN_PASSWORD=" > /opt/tmpfile && \
 echo "AS_ADMIN_NEWPASSWORD=${ADMIN_PASSWORD}" >> /opt/tmpfile && \
 echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" > /opt/pwdfile && \
# domain1
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password && \
 ${PAYARA_PATH}/bin/asadmin start-domain domain1 && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain domain1 && \
 rm -rf ${PAYARA_PATH}/glassfish/domains/domain1/osgi-cache && \
# production
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password --domain_name=production && \
 ${PAYARA_PATH}/bin/asadmin start-domain production && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain production && \
 rm -rf ${PAYARA_PATH}/glassfish/domains/production/osgi-cache && \
 rm /opt/tmpfile

ENV PAYARA_DOMAIN domain1
ENV DEPLOY_DIR ${PAYARA_PATH}/deployments
ENV AUTODEPLOY_DIR ${PAYARA_PATH}/glassfish/domains/${PAYARA_DOMAIN}/autodeploy

# Default payara ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181

ENV POSTBOOT_COMMANDS ${PAYARA_PATH}/post-boot-commands.asadmin

ENTRYPOINT ${PAYARA_PATH}/generate_deploy_commands.sh && ${PAYARA_PATH}/bin/startInForeground.sh  --passwordfile=/opt/pwdfile --postbootcommandfile ${POSTBOOT_COMMANDS} ${PAYARA_DOMAIN}
