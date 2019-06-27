if [ $JANUS_WITH_POSTPROCESSING = "1" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-post-processing"; fi
if [ $JANUS_WITH_BORINGSSL = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV golang-go" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-boringssl --enable-dtls-settimeout"; fi
if [ $JANUS_WITH_DOCS = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV doxygen graphviz" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-docs"; fi
if [ $JANUS_WITH_REST = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV libmicrohttpd-dev"; else export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rest"; fi
if [ $JANUS_WITH_DATACHANNELS = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-data-channels"; fi
if [ $JANUS_WITH_WEBSOCKETS = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-websockets"; fi
if [ $JANUS_WITH_MQTT = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-mqtt"; fi
if [ $JANUS_WITH_PFUNIX = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-unix-sockets"; fi
if [ $JANUS_WITH_RABBITMQ = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rabbitmq"; fi
/usr/sbin/groupadd -r janus && /usr/sbin/useradd -r -g janus janus
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install $JANUS_BUILD_DEPS_DEV ${JANUS_BUILD_DEPS_EXT}

# install libnice
git clone https://gitlab.freedesktop.org/libnice/libnice ${BUILD_SRC}/libnice
cd ${BUILD_SRC}/libnice
./autogen.sh
./configure --prefix=/usr
make
make install

# build libsrtp
# curl -fSL https://github.com/cisco/libsrtp/archive/v2.0.0.tar.gz -o ${BUILD_SRC}/v2.0.0.tar.gz
# tar xzf ${BUILD_SRC}/v2.0.0.tar.gz -C ${BUILD_SRC}
# cd ${BUILD_SRC}/libsrtp-2.0.0
# ./configure --prefix=/usr --enable-openssl
# make shared_library
# make install

# build libconfig
curl -fSL https://hyperrealm.github.io/libconfig/dist/libconfig-1.7.2.tar.gz -o ${BUILD_SRC}/libconfig-1.7.2.tar.gz
tar xzf ${BUILD_SRC}/libconfig-1.7.2.tar.gz -C ${BUILD_SRC}
cd ${BUILD_SRC}/libconfig-1.7.2
./configure --prefix=/usr
make install

# build boringssl
if [ $JANUS_WITH_BORINGSSL = "1" ]; then
    git clone https://boringssl.googlesource.com/boringssl ${BUILD_SRC}/boringssl
    cd ${BUILD_SRC}/boringssl
    sed -i s/" -Werror"//g CMakeLists.txt
    mkdir -p ${BUILD_SRC}/boringssl/build
    cd ${BUILD_SRC}/boringssl/build
    cmake -DCMAKE_CXX_FLAGS="-lrt" ..
    make
    mkdir -p /opt/boringssl
    cp -R ${BUILD_SRC}/boringssl/include /opt/boringssl/
    mkdir -p /opt/boringssl/lib
    cp ${BUILD_SRC}/boringssl/build/ssl/libssl.a /opt/boringssl/lib/
    cp ${BUILD_SRC}/boringssl/build/crypto/libcrypto.a /opt/boringssl/lib/
fi

# build usrsctp
if [ $JANUS_WITH_DATACHANNELS = "1" ]; then
    git clone https://github.com/sctplab/usrsctp ${BUILD_SRC}/usrsctp
    cd ${BUILD_SRC}/usrsctp
    ./bootstrap
    ./configure --prefix=/usr
    make
    make install
fi

# build libwebsockets
if [ $JANUS_WITH_WEBSOCKETS = "1" ]; then
    git clone https://github.com/warmcat/libwebsockets.git ${BUILD_SRC}/libwebsockets
    cd ${BUILD_SRC}/libwebsockets
    git checkout v2.4-stable
    #git checkout v2.4.2
    #git checkout v1.5-chrome47-firefox41
    mkdir ${BUILD_SRC}/libwebsockets/build
    cd ${BUILD_SRC}/libwebsockets/build
    cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" ..
    make
    make install
fi

# build paho.mqtt.c
if [ $JANUS_WITH_MQTT = "1" ]; then
    git clone https://github.com/eclipse/paho.mqtt.c.git ${BUILD_SRC}/paho.mqtt.c
    cd ${BUILD_SRC}/paho.mqtt.c
    make
    make install
fi

# build rabbitmq-c
if [ $JANUS_WITH_RABBITMQ = "1" ]; then
    git clone https://github.com/alanxz/rabbitmq-c ${BUILD_SRC}/rabbitmq-c
    cd ${BUILD_SRC}/rabbitmq-c
    git submodule init
    git submodule update
    autoreconf -i
    ./configure --prefix=/usr
    make
    make install
fi

# build janus-gateway
git clone https://github.com/meetecho/janus-gateway.git ${BUILD_SRC}/janus-gateway
if [ $JANUS_WITH_FREESWITCH_PATCH = "1" ]; then curl -fSL https://raw.githubusercontent.com/krull/docker-misc/master/init_fs/tmp/janus_sip.c.patch -o ${BUILD_SRC}/janus-gateway/plugins/janus_sip.c.patch && cd ${BUILD_SRC}/janus-gateway/plugins && patch < janus_sip.c.patch; fi
cd ${BUILD_SRC}/janus-gateway
git checkout ${JANUS_VERSION}
./autogen.sh
./configure ${JANUS_CONFIG_DEPS} $JANUS_CONFIG_OPTIONS
make
make configs
make install
# folder ownership
chown -R janus:janus /opt/janus
# build cleanup
cd ${BUILD_SRC}
if [ $JANUS_WITH_BORINGSSL = "1" ]; then rm -rf boringssl; fi
if [ $JANUS_WITH_DATACHANNELS = "1" ]; then rm -rf usrsctp; fi
if [ $JANUS_WITH_WEBSOCKETS = "1" ]; then rm -rf libwebsockets; fi
if [ $JANUS_WITH_MQTT = "1" ]; then rm -rf paho.mqtt.c; fi
if [ $JANUS_WITH_RABBITMQ = "1" ]; then rm -rf rabbitmq-c; fi
rm -rf \
        v2.0.0.tar.gz \
        libsrtp-2.0.0 \
        janus-gateway
DEBIAN_FRONTEND=noninteractive apt-get -y --auto-remove purge ${JANUS_BUILD_DEPS_EXT}
DEBIAN_FRONTEND=noninteractive apt-get -y clean
DEBIAN_FRONTEND=noninteractive apt-get -y autoclean
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
rm -rf /usr/share/locale/*
rm -rf /var/cache/debconf/*-old
rm -rf /usr/share/doc/*
rm -rf /var/lib/apt/*
