ARG PYTHON="python:3.10-alpine3.18"
ARG RUNAS="root"

FROM ${PYTHON} AS builder
ENV SYNCPLAY="1.7.3"
RUN apk add gcc musl-dev libffi-dev
RUN sh -c '[ $(getconf LONG_BIT) -eq 64 ] || apk add cargo openssl-dev'
RUN wget https://github.com/Syncplay/syncplay/archive/v${SYNCPLAY}.tar.gz -O- | tar xz
WORKDIR ./syncplay-${SYNCPLAY}/
RUN cat /dev/null > requirements_gui.txt
RUN SNAPCRAFT_PART_BUILD=1 pip wheel --wheel-dir /wheels/ ./

FROM ${PYTHON} AS syncplay
WORKDIR /wheels/
RUN pip wheel PyYaml
COPY --from=builder /wheels/ /wheels/
WORKDIR /release/local/lib/
RUN mkdir $(basename /usr/local/lib/python3.*/) && cd ./python3.*/ && \
    ls /wheels/*.whl | xargs -P0 -n1 unzip -d ./site-packages/
COPY ./boot.py /release/bin/syncplay

FROM ${PYTHON} AS root
RUN sh -c '[ $(getconf LONG_BIT) -eq 64 ] || apk add --no-cache libgcc'
COPY --from=syncplay /release/ /usr/
ENV PYTHONUNBUFFERED=1
EXPOSE 8999
WORKDIR /data/

FROM root AS user
ARG USER_UID=800
ARG USER_GID=800
RUN addgroup -g "${USER_GID}" -S syncplay && \
    adduser -u "${USER_UID}" -S syncplay -G syncplay && \
    chown -R syncplay:syncplay /data
USER syncplay

FROM ${RUNAS}
ENTRYPOINT ["syncplay"]
