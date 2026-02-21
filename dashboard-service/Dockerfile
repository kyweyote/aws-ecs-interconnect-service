FROM alpine:latest

WORKDIR /app

COPY dashboard-service .

ENV PORT=9002
ENV COUNTING_SERVICE_URL="http://counting:9003"

EXPOSE 9002

CMD ["./dashboard-service"]