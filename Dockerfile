FROM alpine:3.20.3 AS build

# Set up build variables
ARG IOQ3DED_VERSION \
    GL_CI_JOB_TOKEN \
    GL_CI_API_V4_URL \
    GL_CI_PROJECT_ID \
    TARGETARCH \
    TARGETVARIANT

# Install necessary build prerequisites
RUN export IOQ3BUILD_COMPILER='clang18 llvm18' \
    && apk add --no-cache \
        ${IOQ3BUILD_COMPILER} \
        lld \
        musl-dev \
        git \
        make \
        curl \
    && mkdir -p /quake /quake.tmp/quake /quake.tmp/baseq3 /quake.tmp/home

# Set the workdir
WORKDIR /quake/extern/ioq3

# Copy files
COPY ./ /quake/

# Build the server
RUN export IOQ3BUILD_BIN_CC='clang-18' \
    && export IOQ3BUILD_BIN_LD=$([ "${TARGETARCH}" != 'riscv64' -a "${TARGETARCH}" != 's390x' ] && printf '%s' 'lld' || printf '%s' 'ld') \
    && export IOQ3BUILD_BIN_STRIP='llvm18-strip' \
    && export IOQ3BUILD_ARG_FUSE_LD=$(printf '-fuse-ld=%s' "${IOQ3BUILD_BIN_LD}")\
    && make \
        -j$(nproc --all) \
        CC="${IOQ3BUILD_BIN_CC} -static ${IOQ3BUILD_ARG_FUSE_LD}" \
        LD="${IOQ3BUILD_BIN_LD} -static" \
        BUILD_STANDALONE=0 \
        BUILD_CLIENT=0 \
        BUILD_SERVER=1 \
        BUILD_GAME_SO=0 \
        BUILD_GAME_QVM=0 \
        BUILD_BASEGAME=0 \
        BUILD_MISSIONPACK=0 \
        BUILD_RENDERER_OPENGL2=0 \
        USE_OPENAL=0 \
        USE_OPENAL_DLOPEN=0 \
        USE_CURL_DLOPEN=0 \
        USE_CODEC_VORBIS=0 \
        USE_CODEC_OPUS=0 \
        USE_MUMBLE=0 \
        USE_VOIP=0 \
        USE_RENDERER_DLOPEN=0 \
        BR=/quake/build/release \
        FULLBINEXT= \
    && curl \
        --fail-with-body \
        -H "JOB-TOKEN: ${GL_CI_JOB_TOKEN}" \
        -T /quake/build/release/ioq3ded \
        "${GL_CI_API_V4_URL}/projects/${GL_CI_PROJECT_ID}/packages/generic/ioq3ded-static/${IOQ3DED_VERSION}/ioq3ded-static-${TARGETARCH}${TARGETVARIANT}" \
    && ${IOQ3BUILD_BIN_STRIP} --strip-all /quake/build/release/ioq3ded \
    && curl \
        --fail-with-body \
        -H "JOB-TOKEN: ${GL_CI_JOB_TOKEN}" \
        -T /quake/build/release/ioq3ded \
        "${GL_CI_API_V4_URL}/projects/${GL_CI_PROJECT_ID}/packages/generic/ioq3ded-static/${IOQ3DED_VERSION}/ioq3ded-static-${TARGETARCH}${TARGETVARIANT}-stripped"

# Build the final container
FROM scratch AS final

# Set labels
LABEL org.opencontainers.image.authors="Emzi0767 <https://gitlab.emzi0767.dev/Emzi0767/ioq3-universal>" \
    org.opencontainers.image.url="https://gitlab.emzi0767.dev/Emzi0767/ioq3-universal" \
    org.opencontainers.image.source="https://gitlab.emzi0767.dev/Emzi0767/ioq3-universal" \
    org.opencontainers.image.title="ioquake3 dedicated server"

# Create working directory
COPY --from=build --chown=666:666 /quake.tmp/quake /quake

# Set working directory and user
WORKDIR /quake
USER 666:666

# Copy server binary
COPY --from=build --chown=666:666 /quake/build/release/ioq3ded /quake/ioq3ded

# Prepare server data
COPY --from=build --chown=666:666 /quake.tmp/baseq3 /quake/baseq3
COPY --from=build --chown=666:666 /quake.tmp/home /quake/home

# Attach a volume for data
VOLUME [ "/quake/baseq3", "/quake/home" ]

# Expose ports
EXPOSE 27960/udp

# Prepare entrypoint
ENTRYPOINT [ "/quake/ioq3ded", \
    "+set", "dedicated", "1", \
    "+set", "sv_allowDownload", "0", \
    "+set", "com_hunkmegs", "64", \
    "+set", "com_homepath", "/quake/home" \
]
CMD [ ]
