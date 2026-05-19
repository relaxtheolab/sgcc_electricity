FROM python:3.12.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV SET_CONTAINER_TIMEZONE=true
ENV CONTAINER_TIMEZONE=Asia/Shanghai
ENV TZ=Asia/Shanghai

ARG TARGETARCH
ARG VERSION
ENV VERSION=${VERSION}
ENV PYTHON_IN_DOCKER='PYTHON_IN_DOCKER'
ENV DISPLAY=:99

COPY scripts/ /app/
WORKDIR /app

RUN apt-get --allow-releaseinfo-change update \
    && apt-get install -y --no-install-recommends \
        jq chromium chromium-driver fonts-noto-cjk tzdata \
        xauth xvfb \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY ./requirements.txt /tmp/requirements.txt

RUN mkdir /data \
    && cd /tmp \
    && python3 -m pip install --upgrade pip \
    && PIP_ROOT_USER_ACTION=ignore pip install \
    --disable-pip-version-check \
    --no-cache-dir \
    -r requirements.txt \
    && rm -rf /tmp/* \
    && pip cache purge \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/log/*

ENV LANG=C.UTF-8

CMD ["xvfb-run", "-a", "--server-args=-screen 0 1920x1080x24", "python3", "main.py"]
