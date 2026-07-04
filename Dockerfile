# ---- Stage 1: Build the signed Android APK ----
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build
WORKDIR /app
COPY . .

# Signing args passed in from CI (see build_image job in .gitlab-ci.yml)
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

# Human-readable version (e.g. "1.0.1") comes from pubspec.yaml, set manually
# by you for real milestones. The build number (e.g. "42") auto-increments
# every pipeline run via GitLab's $CI_PIPELINE_IID, passed in as BUILD_NUMBER.
RUN BUILD_NAME=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1) && \
    echo "Building version $BUILD_NAME+$BUILD_NUMBER" && \
    flutter build apk --release \
      --build-name=$BUILD_NAME \
      --build-number=$BUILD_NUMBER \
      --dart-define=GEMINI_API_KEY=${GEMINI_API_KEY} && \
    echo "$BUILD_NAME+$BUILD_NUMBER" > /tmp/version.txt

# ---- Stage 2: Serve download page + APK via nginx ----
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
COPY --from=flutter-build /app/build/app/outputs/flutter-apk/app-release.apk /usr/share/nginx/html/cal0app-latest.apk
COPY --from=flutter-build /tmp/version.txt /usr/share/nginx/html/version.txt
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080