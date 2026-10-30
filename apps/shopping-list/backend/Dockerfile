FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod tidy
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/shopping-list .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates \
    && addgroup -S -g 65532 app \
    && adduser -S -D -H -u 65532 -G app app
COPY --from=build /out/shopping-list /usr/local/bin/shopping-list
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/shopping-list"]
