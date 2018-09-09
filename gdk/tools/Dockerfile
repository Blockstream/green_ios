FROM debian:stretch@sha256:f1f61086ea01a72b30c7287adee8c929e569853de03b7c462a8ac75e0d0224c4
COPY stretch_deps.sh /deps.sh
COPY requirements.txt /requirements.txt
RUN /deps.sh && rm /deps.sh
ENV ANDROID_NDK=/android-ndk-r17b
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
CMD cd /sdk && ./tools/build.sh --clang
