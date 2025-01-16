FROM --platform=$BUILDPLATFORM golang:1.23.4-alpine AS aaa
ARG VERSION TARGETOS TARGETARCH
ENV GOOS=$TARGETOS
ENV GOARCH=$TARGETARCH
ENV CGO_ENABLED=0
RUN go install -v -trimpath -tags "with_quic with_acme with_utls" \
    -o /go/bin/sing-box \
    -ldflags "-X \"github.com/sagernet/sing-box/constant.Version=$VERSION\" -s -w -buildid=" \
    github.com/sagernet/sing-box/cmd/sing-box@$VERSION

FROM --platform=$TARGETPLATFORM alpine:3.21.0
COPY --from=aaa /go/bin/sing-box /usr/bin/sing-box
RUN apk upgrade --no-cache \
    && apk add --no-cache pwgen tzdata ca-certificates yq curl bind-tools
COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod 755 /usr/bin/entrypoint.sh

VOLUME ["/root/.local/share/certmagic"]
ENTRYPOINT ["entrypoint.sh"]

CMD ["sh", "-c", "sing-box check -c /etc/sing-box/config.json && sing-box run -c /etc/sing-box/config.json"]
