FROM ghcr.io/hassio-addons/base:latest

RUN apk add --no-cache bash

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
