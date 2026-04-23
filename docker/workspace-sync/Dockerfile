FROM alpine:3.23

RUN apk add --no-cache git bash

COPY workspace-sync.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
COPY git-askpass.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/workspace-sync.sh /usr/local/bin/entrypoint.sh /usr/local/bin/git-askpass.sh

ENTRYPOINT ["entrypoint.sh"]
