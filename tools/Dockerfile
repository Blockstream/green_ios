FROM debian:stretch
COPY stretch_deps.sh /deps.sh
COPY requirements.txt /requirements.txt
RUN /deps.sh && rm /deps.sh
VOLUME /sdk
ENV ANDROID_NDK=/android-ndk-r14b
CMD cd /sdk && ./tools/build.sh --clang
