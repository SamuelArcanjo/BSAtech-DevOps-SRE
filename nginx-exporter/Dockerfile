FROM nginx/nginx-prometheus-exporter:1.5.1 AS exporter

FROM alpine:3.23

RUN apk add --no-cache ca-certificates curl

COPY --from=exporter \
  /usr/bin/nginx-prometheus-exporter \
  /usr/bin/nginx-prometheus-exporter

USER 1001:1001

ENTRYPOINT ["/usr/bin/nginx-prometheus-exporter"]