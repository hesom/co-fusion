# Build libglvnd
FROM ubuntu:16.04 as glvnd

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        make \
        automake \
        autoconf \
        libtool \
        pkg-config \
        python \
        libxext-dev \
        libx11-dev \
        x11proto-gl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/libglvnd
RUN git clone --branch=v1.0.0 https://github.com/NVIDIA/libglvnd.git . && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib/x86_64-linux-gnu && \
    make -j"$(nproc)" install-strip && \
    find /usr/local/lib/x86_64-linux-gnu -type f -name 'lib*.la' -delete

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        gcc-multilib \
        libxext-dev:i386 \
        libx11-dev:i386 && \
    rm -rf /var/lib/apt/lists/*

# 32-bit libraries
RUN make distclean && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib/i386-linux-gnu --host=i386-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" && \
    make -j"$(nproc)" install-strip && \
    find /usr/local/lib/i386-linux-gnu -type f -name 'lib*.la' -delete


FROM nvidia/cuda:8.0-devel-ubuntu16.04

COPY --from=glvnd /usr/local/lib/x86_64-linux-gnu /usr/local/lib/x86_64-linux-gnu
COPY --from=glvnd /usr/local/lib/i386-linux-gnu /usr/local/lib/i386-linux-gnu

#COPY 10_nvidia.json /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json

RUN echo '/usr/local/lib/x86_64-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    echo '/usr/local/lib/i386-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    ldconfig

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        libxau6 libxau6:i386 \
        libxdmcp6 libxdmcp6:i386 \
        libxcb1 libxcb1:i386 \
        libxext6 libxext6:i386 \
        libx11-6 libx11-6:i386 && \
    rm -rf /var/lib/apt/lists/*

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES \
        ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
        ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics,compat32,utility,display

# Required for non-glvnd setups.
ENV LD_LIBRARY_PATH /usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

run apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget software-properties-common \
        build-essential \
        freeglut3-dev \
        git \
        gcc-4.9 \
        g++-4.9 \
        libzeroc-ice-dev \
        libeigen3-dev \
        libglew-dev \
        libjpeg-dev \
        libsuitesparse-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        openjdk-8-jdk \
        unzip \
        zlib1g-dev \
        openssl \
        libssl-dev

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 800 --slave /usr/bin/g++ g++ /usr/bin/g++-4.9

# build cmake from source
WORKDIR /opt/cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3.tar.gz && tar -zxvf cmake-3.17.3.tar.gz
RUN cd cmake-3.17.3 && ./bootstrap && make -j8 && make install

WORKDIR /opt/CoFusion/deps

#build opencv
RUN wget https://github.com/Itseez/opencv/archive/3.1.0.zip && \
    unzip 3.1.0.zip && \
    rm 3.1.0.zip && \
    cd opencv-3.1.0 && \
    mkdir -p build && \
    cd build && \
    cmake -E env CXXFLAGS="-w" cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="`pwd`/../install" \
      \
      `# OpenCV: (building is not possible when DBUILD_opencv_video/_videoio is OFF?)` \
      -DBUILD_opencv_flann=ON  \
      -DWITH_CUDA=OFF  \
      -DENABLE_PRECOMPILED_HEADERS=OFF \
      -DBUILD_DOCS=OFF  \
      -DBUILD_TESTS=OFF  \
      -DBUILD_PERF_TESTS=OFF  \
      -DBUILD_opencv_java=OFF  \
      -DBUILD_opencv_python2=OFF  \
      -DBUILD_opencv_python3=OFF  \
      -DBUILD_opencv_features2d=ON  \
      -DBUILD_opencv_calib3d=ON  \
      -DBUILD_opencv_objdetect=ON  \
      -DBUILD_opencv_stitching=OFF  \
      -DBUILD_opencv_superres=OFF  \
      -DBUILD_opencv_shape=OFF  \
      -DWITH_1394=OFF  \
      -DWITH_GSTREAMER=OFF  \
      -DWITH_GPHOTO2=OFF  \
      -DWITH_MATLAB=OFF  \
      -DWITH_TIFF=OFF  \
      -DWITH_VTK=OFF  \
      \
      `# OpenCV-Contrib:` \
      -DBUILD_opencv_surface_matching=ON \
      -DBUILD_opencv_aruco=OFF \
      -DBUILD_opencv_bgsegm=OFF \
      -DBUILD_opencv_bioinspired=OFF \
      -DBUILD_opencv_ccalib=OFF \
      -DBUILD_opencv_contrib_world=OFF \
      -DBUILD_opencv_datasets=OFF \
      -DBUILD_opencv_dnn=OFF \
      -DBUILD_opencv_dpm=OFF \
      -DBUILD_opencv_face=OFF \
      -DBUILD_opencv_fuzzy=OFF \
      -DBUILD_opencv_line_descriptor=OFF \
      -DBUILD_opencv_matlab=OFF \
      -DBUILD_opencv_optflow=OFF \
      -DBUILD_opencv_plot=OFF \
      -DBUILD_opencv_reg=OFF \
      -DBUILD_opencv_rgbd=OFF \
      -DBUILD_opencv_saliency=OFF \
      -DBUILD_opencv_stereo=OFF \
      -DBUILD_opencv_structured_light=OFF \
      -DBUILD_opencv_text=OFF \
      -DBUILD_opencv_tracking=OFF \
      -DBUILD_opencv_xfeatures2d=OFF \
      -DBUILD_opencv_ximgproc=OFF \
      -DBUILD_opencv_xobjdetect=OFF \
      -DBUILD_opencv_xphoto=OFF \
      .. && \
    make -j8 && \
    make install

ARG OpenCV_DIR=/opt/CoFusion/deps/opencv-3.1.0/build

#build boost
RUN wget -O boost_1_62_0.tar.bz2 https://sourceforge.net/projects/boost/files/boost/1.62.0/boost_1_62_0.tar.bz2/download && \
    tar -xjf boost_1_62_0.tar.bz2 && \
    rm boost_1_62_0.tar.bz2 && \
    cd boost_1_62_0 && \
    mkdir -p ../boost && \
    ./bootstrap.sh --prefix=../boost && \
    ./b2 --prefix=../boost --with-filesystem install > /dev/null && \
    cd .. && \
    rm -r boost_1_62_0

ARG BOOST_ROOT=/opt/CoFusion/deps/boost


#build Pangolin
RUN git clone https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \
    mkdir build && cd build && \
    cmake ../ -DAVFORMAT_INCLUDE_DIR="" -DCPP11_NO_BOOST=ON && make -j8
ARG Pangolin_DIR=/opt/CoFusion/deps/Pangolin/build

#build OpenNI2
RUN git clone https://github.com/occipital/OpenNI2.git; \
    cd OpenNI2; \
    make -j8

# build densecrf
RUN git clone https://github.com/martinruenz/densecrf.git && cd densecrf && \
    mkdir -p build && \
    cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fPIC" .. && \
    make -j8

# build gSLICr, see: http://www.robots.ox.ac.uk/~victor/gslicr/
RUN git clone https://github.com/carlren/gSLICr.git && cd gSLICr &&\
    mkdir -p build && cd build && \
    cmake \
        -DOpenCV_DIR="${OpenCV_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_HOST_COMPILER=/usr/bin/gcc-4.9 \
        -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
        -DCMAKE_NVCC_FLAGS="${CMAKE_NVCC_FLAGS} -gencode=arch=compute_70,code=sm_70; -gencode=arch=compute_70,code=compute_70" \
        -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -D_FORCE_INLINES" .. && \
    make -j8

RUN ls /opt/CoFusion/deps/densecrf/build/external/./.

WORKDIR /opt/CoFusion/

COPY . /opt/CoFusion/

RUN mkdir -p build && cd build && \
    cmake \
        -DBOOST_ROOT="${BOOST_ROOT}" \
        -DOpenCV_DIR="${OpenCV_DIR}" \
        -DPangolin_DIR="${Pangolin_DIR}" .. && \
    make -j8

ENV PATH=/opt/CoFusion/build/GUI:${PATH}
