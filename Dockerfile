FROM perl:5.22

ENV PERL_MM_USE_DEFAULT=1 PERL_CARTON_PATH=/carton

COPY cpanfile cpanfile.snapshot /metacpan-api/
WORKDIR /metacpan-api

RUN apt-get update && \
    apt-get install -y libgmp-dev rsync && \
    cpanm App::cpm && \
    cpm install -g Carton && \
    useradd -m metacpan-api -g users && \
    mkdir /carton /CPAN && \
    cpm install -L /carton && \
    rm -fr /root/.cpanm /root/.perl-cpm /var/cache/apt/lists/* /tmp/*

COPY . /metacpan-api

RUN chown -R metacpan-api:users /metacpan-api /carton /CPAN

VOLUME /carton

VOLUME /CPAN

USER metacpan-api:users

EXPOSE 5000

CMD ["carton", "exec", "plackup", "-p", "5000", "-r"]
