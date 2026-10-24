# Runner image for the nix-config opencode scheduler.
FROM nixos/nix:latest
RUN mkdir -p /app /etc/nixos
WORKDIR /app
COPY . /app
RUN chmod +x /app/tools/*.sh
CMD ["/bin/bash", "/app/tools/run-scheduler.sh"]
