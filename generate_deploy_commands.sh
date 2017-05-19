if [ x$1 != x ]
  then
    DEPLOY_OPTS="$*"
fi

echo '# deployments after boot' > $POST_BOOT_COMMANDS
for deployment in "${DEPLOY_DIR}"/*
  do
    echo "deploy --force --enabled=true $DEPLOY_OPTS $deployment" >> $DEPLOY_COMMANDS
done