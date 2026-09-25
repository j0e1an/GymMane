FROM ghcr.io/cirruslabs/flutter:3.41.9 AS build
WORKDIR /src
COPY . .
RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release --base-href / --pwa-strategy=none

FROM python:3.12-alpine
RUN adduser -D -u 10001 gymmane
WORKDIR /app
COPY server/auth_server.py /app/auth_server.py
COPY --from=build /src/build/web /app/web
USER gymmane
ENV PORT=8080 \
    WEB_ROOT=/app/web
EXPOSE 8080
CMD ["python", "-u", "/app/auth_server.py"]
