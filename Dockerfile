# ---- Stage 1: Build the signed Android APK ----
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build
WORKDIR /app
COPY . .

ARG ANDROID_KEYSTORE_PATH
ARG ANDROID_KEYSTORE_PASSWORD
ARG ANDROID_KEY_ALIAS
ARG ANDROID_KEY_PASSWORD
ARG GEMINI_API_KEY
ARG BUILD_NUMBER=1

ENV ANDROID_KEYSTORE_PATH=/app/android/app/release.jks
ENV ANDROID_KEYSTORE_PASSWORD=${ANDROID_KEYSTORE_PASSWORD}
ENV ANDROID_KEY_ALIAS=${ANDROID_KEY_ALIAS}
ENV ANDROID_KEY_PASSWORD=${ANDROID_KEY_PASSWORD}

RUN flutter pub get

RUN BUILD_NAME=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1) && \
    echo "Building version $BUILD_NAME+$BUILD_NUMBER" && \
    flutter build apk --release \
      --build-name=$BUILD_NAME \
      --build-number=$BUILD_NUMBER \
      --dart-define=GEMINI_API_KEY=${GEMINI_API_KEY} && \
    echo "$BUILD_NAME+$BUILD_NUMBER" > /tmp/version.txt && \
    mkdir -p /tmp/out && \
    cp build/app/outputs/flutter-apk/app-release.apk /tmp/out/cal0app-latest.apk && \
    cp build/app/outputs/flutter-apk/app-release.apk "/tmp/out/cal0app-v${BUILD_NAME}-build${BUILD_NUMBER}.apk"

# ---- Stage 2: Serve download page + APK via nginx ----
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
COPY --from=flutter-build /tmp/out/ /usr/share/nginx/html/
COPY --from=flutter-build /tmp/version.txt /usr/share/nginx/html/version.txt
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080