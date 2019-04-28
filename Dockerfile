FROM openjdk:11.0.3-jdk-slim-stretch as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    time \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --system nonroot
USER nonroot
RUN mkdir -p /home/nonroot/build && cd /home/nonroot/build

COPY src src

RUN mkdir -p /home/nonroot/build/target/classes /home/nonroot/build/target/lib && \
    javac -d /home/nonroot/build/target/classes --module-source-path src $(find src -name "*.java") && \
    jar --create --file=/home/nonroot/build/target/lib/org.astro@1.0.jar -C /home/nonroot/build/target/classes/org.astro . && \
    jar --create --file=/home/nonroot/build/target/lib/com.greetings.jar --main-class=com.greetings.Main -C /home/nonroot/build/target/classes/com.greetings .

# This takes 13+ seconds on my machine; shame we can't reuse an existing stripped down one in some way?
RUN time jlink \
    --add-modules com.greetings \
    --module-path /home/nonroot/build/target/lib \
    --verbose \
    --strip-debug \
    --compress 2 \
    --no-header-files \
    --no-man-pages \
    --output /home/nonroot/build/target/greetings-runtime \
    && time strip -p --strip-unneeded $(find /home/nonroot/build/target/greetings-runtime -name *.so)

FROM panga/alpine:3.7-glibc2.25

COPY --from=builder /home/nonroot/build/target/greetings-runtime /opt/greetings-runtime

ENV LANG=C.UTF-8 \
    PATH=${PATH}:/opt/greetings-runtime/bin

ARG JVM_OPTS
ENV JVM_OPTS=${JVM_OPTS}

CMD java ${JVM_OPTS} --module com.greetings
