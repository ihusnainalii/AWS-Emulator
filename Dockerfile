FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

ARG TARGETARCH

RUN ARCH="$(uname -m)" \
    && if [ -n "$TARGETARCH" ]; then \
         case "$TARGETARCH" in \
           "arm64") ARCH="aarch64" ;; \
           "amd64") ARCH="x86_64" ;; \
         esac; \
       fi \
    && curl -Lo /tmp/aws-emulator.rpm "https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/latest/aws-emulator-${ARCH}.rpm" \
    && rpm -i /tmp/aws-emulator.rpm \
    && rm /tmp/aws-emulator.rpm \
    && mkdir -p /home/emulator/.aws/emulator \
    && chown -R 1000:1000 /home/emulator

USER 1000
ENV HOME=/home/emulator
EXPOSE 9297
ENTRYPOINT ["aws-emulator", "-b", "0.0.0.0"]
