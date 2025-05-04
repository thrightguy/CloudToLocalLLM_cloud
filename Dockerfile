# Use a Flutter-enabled Docker image for building
FROM cirrusci/flutter:stable AS build

WORKDIR /app
COPY . .
RUN flutter pub get && \
    flutter build web --release

# Use a lightweight server image to serve the web app
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
