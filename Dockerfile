FROM cirrusci/flutter:3.3.10 AS builder

WORKDIR /app

COPY . .

RUN flutter pub get
RUN flutter build web --release

FROM nginx:1.23-alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
