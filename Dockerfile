# Use a small Debian image as the container's Linux environment.
FROM debian:bookworm-slim

# Install only the command-line tools used by the app and CI scripts.
# mawk provides awk; procps provides free and uptime.
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        bash \
        coreutils \
        libc-bin \
        hostname \
        iputils-ping \
        mawk \
        procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the application into the image and make it executable.
COPY app/app.sh /app/app.sh
RUN chmod +x /app/app.sh

# Pass arguments such as "help" or "system-info" to the application.
ENTRYPOINT ["/app/app.sh"]
CMD ["help"]
