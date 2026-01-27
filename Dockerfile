ARG SLIM_BUILD
ARG MAYBE_BASE_BUILD=${SLIM_BUILD:+server-base-slim}
ARG BASE_BUILD=${MAYBE_BASE_BUILD:-server-base}

################### Web Server Base
FROM metacpan/metacpan-base:main-20250531-090128 AS server-base
FROM metacpan/metacpan-base:main-20250531-090129-slim AS server-base-slim

################### CPAN Prereqs
FROM server-base AS build-cpan-prereqs
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

WORKDIR /app/

COPY cpanfile cpanfile.snapshot ./
RUN \
    --mount=type=cache,target=/root/.perl-cpm,sharing=private \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot
EOT

################### Web Server
# false positive
# hadolint ignore=DL3006
FROM ${BASE_BUILD} AS server
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

WORKDIR /app/

COPY app.psgi log4perl* metacpan_server.* metacpan_server_local.* ./
COPY es es
COPY bin bin
COPY lib lib
COPY root root

RUN mkdir -p var && chown metacpan var

COPY --from=build-cpan-prereqs /app/local local

ENV PERL5LIB="/app/local/lib/perl5"
ENV PATH="/app/local/bin:${PATH}"
ENV METACPAN_SERVER_HOME=/app

VOLUME /CPAN

USER metacpan

CMD [ \
    "/uwsgi.sh", \
    "--http-socket", ":8000" \
]

EXPOSE 8000

HEALTHCHECK --start-period=3s CMD [ "curl", "--fail", "http://localhost:8000/healthcheck" ]

################### Development Server
FROM server AS develop
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

ENV COLUMNS=120
ENV PLACK_ENV=development

USER root

COPY cpanfile cpanfile.snapshot ./

RUN \
    --mount=type=cache,target=/root/.perl-cpm \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot --with-develop
    chown -R metacpan:users ./
EOT

USER metacpan

################### Test Runner
FROM develop AS test
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

ENV PLACK_ENV=

USER root

RUN \
    --mount=type=cache,target=/root/.perl-cpm \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot --with-test
EOT

COPY .perlcriticrc .perltidyrc perlimports.toml precious.toml .editorconfig metacpan_server_testing.* ./
COPY t t
COPY test-data test-data

RUN mkdir -p var/t && chown metacpan var/t

USER metacpan
CMD [ "prove", "-l", "-r", "-j", "2", "t" ]

################### Production Server
FROM server AS production

USER metacpan
