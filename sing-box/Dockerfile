FROM golang:1.23.1-alpine as aaa
ARG VERSION
RUN CGO_ENABLED=0 go install -v -trimpath -tags "with_quic with_acme with_utls" \
    -ldflags "-X \"github.com/sagernet/sing-box/constant.Version=$VERSION\" -s -w -buildid=" \
    github.com/sagernet/sing-box/cmd/sing-box@$VERSION

FROM alpine:3.20.3
COPY --from=aaa /go/bin/sing-box /usr/bin/sing-box
RUN apk upgrade --no-cache \
    && apk add --no-cache pwgen tzdata ca-certificates yq curl bind-tools
COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod 755 /usr/bin/entrypoint.sh

VOLUME ["/root/.local"]
ENTRYPOINT ["entrypoint.sh"]

CMD sing-box check -c /etc/sing-box/config.json \
    && sing-box run -c /etc/sing-box/config.json
