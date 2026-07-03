# ---- Stage 1: Build the signed Android APK ----
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build
WORKDIR /app
COPY . .

# Signing args passed in from CI (see build_image job in .gitlab-ci.yml)
ARG ANDROID_KEYSTORE_PATH
ARG ANDROID_KEYSTORE_PASSWORD
ARG ANDROID_KEY_ALIAS
ARG ANDROID_KEY_PASSWORD

# release.jks was decoded onto the CI runner and copied in with the rest
# of the repo context; build.gradle.kts reads these as env vars.
ENV ANDROID_KEYSTORE_PATH=/app/android/app/release.jks
ENV ANDROID_KEYSTORE_PASSWORD=${ANDROID_KEYSTORE_PASSWORD}
ENV ANDROID_KEY_ALIAS=${ANDROID_KEY_ALIAS}
ENV ANDROID_KEY_PASSWORD=${ANDROID_KEY_PASSWORD}

RUN flutter pub get
RUN flutter build apk --release

# ---- Stage 2: Serve download page + APK via nginx ----
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
COPY --from=flutter-build /app/build/app/outputs/flutter-apk/app-release.apk /usr/share/nginx/html/cal0app-latest.apk
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080