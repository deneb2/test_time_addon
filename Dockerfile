ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install required packages
RUN apk add --no-cache bash

# Copy the run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Entry point for container
CMD ["/run.sh"]