FROM golang:latest AS builder
WORKDIR /root
COPY . .
RUN go build main.go

FROM alpine:latest
RUN apk update && apk install -f ca-certificates
WORKDIR /root
COPY --from=builder  /root/main /root/x-ui
COPY bin/. /root/bin/.
VOLUME [ "/etc/x-ui" ]
CMD [ "./x-ui" ]