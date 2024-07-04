FROM local/gentoo-crossdev-base:stable

ADD target-files/crossdev.conf /etc/portage/repos.conf/

RUN mkdir -p /var/db/repos/crossdev/{profiles,metadata} && \
    echo 'crossdev' > /var/db/repos/crossdev/profiles/repo_name && \
    echo 'masters = gentoo'\n\
         'thin-manifests = true' > /var/db/repos/crossdev/metadata/layout.conf && \
    chown -R portage:portage /var/db/repos/crossdev

RUN emerge --quiet dev-util/ccache
RUN echo 'PATH="/usr/lib/ccache/bin:${PATH}"'\n\
         'CCACHE_PREFIX="distcc"' > /etc/conf.d/distccd && \
    echo 'CCACHE_DIR="/var/cache/ccache"'\n\
         'DISTCC_DIR="/var/tmp/portage/.distcc"' > /etc/env.d/03distcc_ccache && \
    mkdir "/var/cache/ccache/" && \
    cd "/var/cache/ccache/" && \
    mkdir -p "{a..z} {0..9} tmp"  && \
    find /var/cache/ccache -type d -exec chown distcc:portage "{}" +


ARG BINUTIL_VER='~2.42'
ARG GCC_VER='~14.1.1_p20240615'
ARG KERNEL_VER='~6.9'
ARG LIBC_VER='~2.39'
ARG TARGET='riscv64-unknown-linux-gnu'

RUN crossdev -t "${TARGET}" --b "${BINUTIL_VER}" --g "${GCC_VER}" --k "${KERNEL_VER}" --l "${LIBC_VER}"
#RUN crossdev -t --b "${BINUTIL_VER}" --k "${KERNEL_VER}" --g "${GCC_VER}" --l "${LIBC_VER}" "${TARGET}"


#
#
#
#ARG TARGET=alpha-unknown-linux-gnu
#ARG ARCH=alpha
#
#ARG STAGE3_FILE="stage3-${ARCH}-${STAGE3_DATE}.tar.bz2"



# Define how to start distccd by default
# (see "man distccd" for more information)
ENTRYPOINT [\
  "distccd", \
  "--daemon", \
  "--no-detach", \
  "--user", "distcc", \
  "--port", "3636", \
  "--stats", \
  "--stats-port", "3637", \
  "--log-stderr", \
  "--listen", "0.0.0.0"\
]

# By default the distcc server will accept clients from everywhere.
# Feel free to run the docker image with different values for the
# following params.
CMD [\
  "--allow", "0.0.0.0/0", \
  "--nice", "5", \
  "--jobs", "5" \
]

# 3632 is the default distccd port
# 3633 is the default distccd port for getting statistics over HTTP
EXPOSE \
  3636/tcp \
  3637/tcp

# We check the health of the container by checking if the statistics
# are served. (See
# https://docs.docker.com/engine/reference/builder/#healthcheck)
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://0.0.0.0:3637/ || exit 1
