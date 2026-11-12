FROM apache/apisix:3.13.0-debian
COPY conf/config.yaml /usr/local/apisix/conf/config.yaml
COPY conf/apisix.yaml /usr/local/apisix/conf/apisix.yaml
