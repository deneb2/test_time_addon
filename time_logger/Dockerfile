# Use the appropriate base image for Raspberry Pi 4
FROM homeassistant/arm64-base:latest

RUN apk add --no-cache bash

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
