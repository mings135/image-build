FROM nginx:1.29.5-alpine

COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod 755 /usr/bin/entrypoint.sh
RUN apk upgrade --no-cache \
    && apk add --no-cache certbot

EXPOSE 443/tcp
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
