ARG BUILD_FROM=ghcr.nju.edu.cn/poiig/sgcc_electricity:latest
FROM ${BUILD_FROM}

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
