FROM metacpan/metacpan-base:latest

COPY cpanfile cpanfile.snapshot /metacpan-api/
WORKDIR /metacpan-api

# CPM installations of dependencies does not install or run tests. This is
# because the modules themselves have been tested, and the metacpan use of the
# modules is tested by the test suite. Removing the tests, reduces the overall
# size of the images.
RUN mkdir /CPAN \
    && apt-get update \
    && apt-get install -y --no-install-recommends rsync=3.2.3-4+deb11u1 jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && cpm install --global \
    && git config --global --add safe.directory /metacpan-api \
    && rm -fr /root/.cpanm /root/.perl-cpm /var/cache/apt/lists/* /tmp/*

VOLUME /CPAN

EXPOSE 5000

CMD [ "/wait-for-it.sh", "${PGDB}",  "--", "${API_SERVER}", "./bin/api.pl" ]
