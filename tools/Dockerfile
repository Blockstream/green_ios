FROM debian:stretch@sha256:c908a4fcb2b2a1953bd40ebc12d9a4116868d72540efc27502ee6c2395b8a1e9
COPY stretch_deps.sh /deps.sh
COPY requirements.txt /requirements.txt
RUN /deps.sh && rm /deps.sh
VOLUME /sdk
ENV ANDROID_NDK=/android-ndk-r14b
CMD cd /sdk && ./tools/build.sh --clang
