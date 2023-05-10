FROM ubuntu:22.04
LABEL maintainer=duartemolha@gmail.com

# these args need to be are provided in the build command
ARG DB_HOST
ARG DB_PORT
ARG DB_USER
ARG DB_PASSWORD
ARG DB_VERSION
ARG VERSION
ARG ASSEMBLY
ARG MAX_REQUESTS_PER_SECOND

# these are derived variables
ARG VEP_FASTA="/root/.vep/homo_sapiens/${VERSION}_${ASSEMBLY}/Homo_sapiens.${ASSEMBLY}.dna.toplevel.fa"
ARG VEP_CACHE_DIR="/root/.vep/homo_sapiens/${VERSION}_${ASSEMBLY}"
ARG MAX_REQUESTS_PER_SECOND_EXCEEDED=$((MAX_REQUESTS_PER_SECOND + 1))
ARG MAX_REQUESTS_PER_HOUR=$((MAX_REQUESTS_PER_SECOND * 3600))

ARG BRANCH=release/$VERSION


ENV DEBIAN_FRONTEND=noninteractive
ENV PERL5LIB=/opt/ensembl/modules:/opt/ensembl-variation/modules:/opt/ensembl-vep/modules:/opt/ensembl-compara/modules:/opt/ensembl-funcgen/modules:/opt/ensembl-metadata/modules:/opt/ensembl-io/modules:/opt/bioperl

ENV HTSLIB_DIR=/opt/src/htslib-1.13
ENV KENT_SRC=/opt/src/kent/src
ENV PATH="${PATH}:/opt/ensembl-variation/C_code:/opt/ensembl-git-tools/bin"

# update and install compilers
RUN apt-get update && apt-get install -y \
    make build-essential ca-certificates

# InsTALL DEPENDENCIES
RUN apt-get install -y \
    cpanminus \
    git \
    libcurl4-openssl-dev libssl-dev \
    libxml2 libxml2-dev zlib1g zlib1g-dev libexpat1 libexpat1-dev libbz2-dev liblzma-dev libpng-dev \
    mysql-client libmysqlclient-dev \ 
    libany-uri-escape-perl \
    libchi-perl \
    libcarp-clan-perl \
    libcatalyst-perl \
    libcatalyst-action-renderview-perl \
    libcatalyst-action-rest-perl \
    libcatalyst-component-instancepercontext-perl \
    libcatalyst-devel-perl \
    libcatalyst-log-log4perl-perl \
    libcatalyst-modules-perl \
    libcatalyst-plugin-cache-perl \
    libcatalyst-plugin-configloader-perl \
    libcatalyst-plugin-static-simple-perl \
    libcatalyst-view-json-perl \
    libcatalyst-view-tt-perl \
    libconfig-general-perl \
    libdata-stag-perl \
    libdbd-mysql-perl \
    libdbd-sqlite3-perl \
    libdbi-perl \
    libhash-merge-perl \
    libio-string-perl \
    libjson-perl \
    libjson-xs-perl \
    liblist-moreutils-perl \
    liblog-log4perl-perl \
    libmodule-build-perl \
    libmodule-install-perl \
    libmojolicious-perl \
    libmoose-perl \
    libnamespace-autoclean-perl \
    libnet-cidr-lite-perl \
    libparse-recdescent-perl \
    libreadonly-perl \
    libreadonlyx-perl \
    libtest-json-perl \
    libtest-most-perl \
    libtest-time-perl \
    libtest-xml-simple-perl \
    libtest-xpath-perl \
    libtest-warnings-perl \
    libtry-tiny-perl \
    liburi-find-perl \
    libxml-simple-perl \
    libxml-writer-perl \
    libyaml-perl \
    libyaml-syck-perl \
    starman \
    sqlite3 \
    unzip \
    wget \
    samtools \
    tabix

WORKDIR /opt/bioperl
RUN wget -nc https://github.com/bioperl/bioperl-live/archive/release-1-6-924.zip && \
    unzip release-1-6-924.zip && rm -f release-1-6-924.zip

WORKDIR /opt/bioperl/bioperl-live-release-1-6-924
RUN perl ./Build.PL --prefix=/opt/bioperl --accept && ./Build 

WORKDIR /opt/bioperl
RUN cp -R /opt/bioperl/bioperl-live-release-1-6-924/Bio* ./ && rm -rf /opt/bioperl/bioperl-live-release-1-6-924

WORKDIR /opt
RUN git clone --depth 1 https://github.com/Ensembl/ensembl-git-tools.git
WORKDIR /opt/ensembl-git-tools
RUN git clean -d -X -f && rm -rf /opt/ensembl-git-tools/.git


WORKDIR /opt
RUN git ensembl --clone --shallow --depth 1 --branch=${BRANCH} --secondary_branch=main rest

WORKDIR /opt/ensembl-vep
RUN perl INSTALL.pl -a cf --CACHE_VERSION ${VERSION} -p -t -l --NO_BIOPERL -s homo_sapiens -y ${ASSEMBLY}

RUN bgzip -@ 10 -c ${VEP_FASTA} > "${VEP_FASTA}.gz"
ARG VEP_FASTA="${VEP_FASTA}.gz"
RUN samtools faidx ${VEP_FASTA}

WORKDIR /opt

WORKDIR ${HTSLIB_DIR}
RUN wget https://github.com/samtools/htslib/releases/download/1.13/htslib-1.13.tar.bz2 && \
    tar xjf htslib-1.13.tar.bz2 -C ../ && rm -f htslib-1.13.tar.bz2 && \
    ./configure --prefix=/usr/local && make && make install && ldconfig

#Build Kent lib
WORKDIR /opt/src

RUN wget https://github.com/ucscGenomeBrowser/kent/archive/v335_base.tar.gz && \
    tar xzf v335_base.tar.gz && rm -rf v335_base.tar.gz kent-335_base/java kent-335_base/python && \
    mv kent-335_base kent

WORKDIR ${KENT_SRC}
RUN sed -i "s/CC=gcc/CC=gcc -fPIC/g" ./inc/common.mk && \
    sed -i "1109s/my_bool/bool/" ./hg/lib/jksql.c   && \
    sed -i "1110s/MYSQL_OPT_SSL_VERIFY_SERVER_CERT/CLIENT_SSL_VERIFY_SERVER_CERT/" ./hg/lib/jksql.c
WORKDIR ${KENT_SRC}/lib
RUN make
WORKDIR ${KENT_SRC}/jkOwnLib
RUN make && ln -s ${KENT_SRC}/lib/x86_64/* ${KENT_SRC}/lib/

WORKDIR /opt/ensembl-rest
COPY ensembl_rest_template.conf ensembl_rest.conf.default

# Replace the password placeholder in the configuration template and save it as 'conf'
RUN sed -i "s/{{DB_HOST}}/${DB_HOST}/" ensembl_rest.conf.default
RUN sed -i "s/{{DB_PORT}}/${DB_PORT}/" ensembl_rest.conf.default
RUN sed -i "s/{{DB_USER}}/${DB_USER}/" ensembl_rest.conf.default
RUN sed -i "s/{{DB_VERSION}}/${DB_VERSION}/" ensembl_rest.conf.default
RUN sed -i "s/{{VERSION}}/${VERSION}/" ensembl_rest.conf.default
RUN sed -i "s@{{VEP_FASTA}}@${VEP_FASTA}@" ensembl_rest.conf.default
RUN sed -i "s@{{VEP_CACHE_DIR}}@${VEP_CACHE_DIR}@" ensembl_rest.conf.default
RUN sed -i "s@{{VEP_PLUGIN_CONFIG}}@@" ensembl_rest.conf.default
RUN sed -i "s@{{VEP_PLUGIN_DIR}}@@" ensembl_rest.conf.default


RUN if [ "${DB_PASSWORD}" = "" ]; then \
    sed -i "s#{{DB_PASSWORD}}##g" ensembl_rest.conf.default; \
    else \
    sed -i "s#{{DB_PASSWORD}}#pass = ${DB_PASSWORD}#g" ensembl_rest.conf.default; \
    fi 



RUN if [ "${ASSEMBLY}" = "GRCh38" ]; then \
    sed -i 's/{{COMPARA_SETTINGS}}/compara_grch37.conf = compara.conf/g' ensembl_rest.conf.default; \
    elif [ "${ASSEMBLY}" = "GRCh37" ]; then \
    sed -i 's/{{COMPARA_SETTINGS}}/compara.conf = compara_grch37.conf/g' ensembl_rest.conf.default; \
    fi

COPY ensembl_rest.psgi ensembl_rest.psgi
RUN sed -i "s@{{MAX_REQUESTS_PER_SECOND}}@${MAX_REQUESTS_PER_SECOND}@" ensrest.psgi

RUN cpanm Bio::DB::HTS Bio::DB::BigFile Test::Time::HiRes Readonly::XS
RUN cpanm Task::Catalyst
RUN cpanm Catalyst::Devel
RUN cpanm --installdeps .
RUN perl Makefile.PL


EXPOSE 80
CMD ["./script/ensembl_rest_server.pl","-p","80"]
