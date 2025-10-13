FROM python:3.11-slim
RUN pip install --no-cache-dir tzlocal
COPY run.sh /run.sh
RUN chmod +x /run.sh
ENTRYPOINT ["/run.sh"]