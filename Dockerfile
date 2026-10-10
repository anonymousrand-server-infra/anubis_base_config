# need this to pull things like `cp` into the barebones anubis image; we use busybox instead of
# alpine since it has statically-compiled binaries so we don't need to also pull dependencies
FROM busybox:musl AS busybox

FROM ghcr.io/techarohq/anubis:latest

ARG DOCKER_ROOT_USER

USER ${DOCKER_ROOT_USER}

# install busybox's statically-compiled binaries for basic shell commands in anubis image
# (note that `busybox --install` doesn't seem to work)
COPY --from=busybox /bin/* /bin/

# merge anubis configs from all configured places herr (e.g. a service's + the base)
# `COPY` doesn't work if `CONFIG_SRC_FILES` holds multiple space-separated files, so we instead
# make a temporary bind of the dockerfile's context to `/tmp_bind/` inside the container and `cp`
# this does require us to mount a large context, but this service shouldn't be restarted much
ARG CONFIG_SRC_FILES
ARG CONFIG_DEST_DIR

RUN --mount=type=bind,target=/tmp_bind/ \
    if [ -n "${CONFIG_SRC_FILES}" ]; then \
        mkdir -p ${CONFIG_DEST_DIR} \
        && cd /tmp_bind/ && cp -r ${CONFIG_SRC_FILES} ${CONFIG_DEST_DIR}; \
    fi

# set the right permissions for the private key inside the container: only accessible to root
# (we do this here instead of in a `pre_start` hook since we aren't bind mounting this file,
# and since `pre_start`s run their own container they cannot access the files copied to this one)
ARG ANUBIS_PRIVKEY_DEST_FILE

RUN chown ${DOCKER_ROOT_USER} ${ANUBIS_PRIVKEY_DEST_FILE}
RUN chmod 600 ${ANUBIS_PRIVKEY_DEST_FILE}
