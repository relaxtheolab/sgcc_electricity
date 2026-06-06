# 阶段 1：系统依赖（变化最少，缓存命中率最高）
FROM python:3.12.11-slim-bookworm AS system-deps

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get --allow-releaseinfo-change update \
    && apt-get install -y --no-install-recommends \
        jq chromium chromium-driver fonts-noto-cjk tzdata \
    && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/* /var/log/* /tmp/* \
    && apt-get clean

# 阶段 2：Python 依赖（仅在 requirements.txt 变化时重建）
FROM system-deps AS pip-deps

COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip \
    && PIP_ROOT_USER_ACTION=ignore pip install \
    --disable-pip-version-check \
    -r /tmp/requirements.txt \
    && rm -rf /tmp/requirements.txt

# 阶段 3：应用代码（变化最频繁，单独一层）
FROM pip-deps

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LANG=C.UTF-8
ENV SET_CONTAINER_TIMEZONE=true
ENV CONTAINER_TIMEZONE=Asia/Shanghai
ENV TZ=Asia/Shanghai

ARG VERSION
ARG BUILD_DATE
ENV VERSION=${VERSION:-latest}
ENV BUILD_DATE=${BUILD_DATE}
ENV PYTHON_IN_DOCKER='PYTHON_IN_DOCKER'

WORKDIR /app
COPY scripts/ /app/

RUN mkdir -p /data

CMD ["python3", "main.py"]
