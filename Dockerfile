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

################### Dev Prereqs
FROM build-cpan-prereqs AS build-dev-prereqs
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

USER root

RUN \
    --mount=type=cache,target=/root/.perl-cpm \
<<EOT
    cpm install --show-build-log-on-failure --resolver=snapshot --with-develop --with-test
EOT

COPY bin/install-precious /tmp/install-precious
RUN /tmp/install-precious /usr/local/bin

################### Development Server
FROM server AS server-dev

ENV PLACK_ENV=development

COPY --from=build-dev-prereqs /app/local local
COPY --from=build-dev-prereqs /usr/local/bin/precious /usr/local/bin/omegasort /usr/local/bin/

COPY .perlcriticrc .perltidyrc perlimports.toml precious.toml .editorconfig metacpan_server_testing.* ./
COPY t t
COPY test-data test-data

USER root
RUN mkdir -p var/t && chown -R metacpan var/t /app/local
USER metacpan

################### Test Runner
FROM server-dev AS test

ENV PLACK_ENV=

CMD [ "prove", "-l", "-r", "-j", "2", "t" ]

################### Development
FROM server-dev AS dev

CMD [ "bash" ]

################### Production Server
FROM server AS production
