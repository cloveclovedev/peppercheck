# syntax=docker/dockerfile:1
FROM golang:1.26 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/peppercheck ./cmd/peppercheck

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=build /out/peppercheck /peppercheck
USER nonroot:nonroot
ENTRYPOINT ["/peppercheck"]
CMD ["api"]
