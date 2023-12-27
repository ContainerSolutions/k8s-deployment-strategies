FROM golang:1.21-alpine AS build
RUN apk --no-cache add git
COPY . $GOPATH/src/app
WORKDIR $GOPATH/src/app
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM scratch
COPY --from=build /go/src/app/app /app
EXPOSE 8080 8086 9101
CMD ["/app"]
