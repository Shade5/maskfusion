#!/bin/bash -e
#
# This is a build script for MaskFusion.
#
# Use parameters:
# `--install-packages` to install required Ubuntu packages
# `--install-cuda` to install the NVIDIA CUDA suite
# `--build-dependencies` to build third party dependencies
#
# Example:
#   ./build.sh --install-packages --build-dependencies
#
#   which will create:
#   - ./deps/densecrf
#   - ./deps/gSLICr
#   - ./deps/OpenNI2
#   - ./deps/Pangolin
#   - ./deps/opencv-3.1.0
#   - ./deps/boost (unless env BOOST_ROOT is defined)
#   - ./deps/coco
#   - ./deps/Mask_RCNN

# Function that executes the clone command given as $1 iff repo does not exist yet. Otherwise pulls.
# Only works if repository path ends with '.git'
# Example: git_clone "git clone --branch 3.4.1 --depth=1 https://github.com/opencv/opencv.git"
function git_clone(){
  repo_dir=`basename "$1" .git`
  git -C "$repo_dir" pull 2> /dev/null || eval "$1"
}

# Ensure that current directory is root of project
cd $(dirname `realpath $0`)

# Enable colors
source deps/bashcolors/bash_colors.sh
function highlight(){
  clr_magentab clr_bold clr_white "$1"
}

highlight "Starting MaskFusion build script ..."
echo "Available parameters:
        --install-packages
        --install-cuda
        --build-dependencies"


if [[ $* == *--build-dependencies* ]] ; then

  # Build dependencies
  mkdir -p deps
  cd deps

  if [ -z "${BOOST_ROOT}" -a ! -d boost ]; then
    highlight "Building boost..."
    wget --no-clobber -O boost_1_62_0.tar.bz2 https://sourceforge.net/projects/boost/files/boost/1.62.0/boost_1_62_0.tar.bz2/download
    tar -xjf boost_1_62_0.tar.bz2 > /dev/null
    rm boost_1_62_0.tar.bz2
    cd boost_1_62_0
    mkdir -p ../boost
    ./bootstrap.sh --prefix=../boost
    ./b2 --prefix=../boost --with-filesystem install > /dev/null
    cd ..
    rm -r boost_1_62_0
    BOOST_ROOT=$(pwd)/boost
  fi

  # build pangolin
  highlight "Building pangolin..."
  git_clone "git clone --depth=1 https://github.com/stevenlovegrove/Pangolin.git"
  cd Pangolin
  git pull
  mkdir -p build
  cd build
  cmake -DAVFORMAT_INCLUDE_DIR="" -DCPP11_NO_BOOST=ON ..
  make -j8
  Pangolin_DIR=$(pwd)
  cd ../..

  # build OpenNI2
  highlight "Building openni2..."
  git_clone "git clone --depth=1 https://github.com/occipital/OpenNI2.git"
  cd OpenNI2
  git pull
  make -j8
  cd ..

  # build freetype-gl-cpp
  highlight "Building freetype-gl-cpp..."
  git_clone "git clone --depth=1 --recurse-submodules https://github.com/martinruenz/freetype-gl-cpp.git"
  cd freetype-gl-cpp
  mkdir -p build
  cd build
  cmake -DBUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX="`pwd`/../install" -DCMAKE_BUILD_TYPE=Release ..
  make -j8
  make install
  cd ../..

  # build DenseCRF, see: http://graphics.stanford.edu/projects/drf/
  highlight "Building densecrf..."
  git_clone "git clone --depth=1 https://github.com/martinruenz/densecrf.git"
  cd densecrf
  git pull
  mkdir -p build
  cd build
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fPIC" \
    ..
  make -j8
  cd ../..

  # build gSLICr, see: http://www.robots.ox.ac.uk/~victor/gslicr/
  highlight "Building gslicr..."
  git_clone "git clone --depth=1 https://github.com/carlren/gSLICr.git"
  cd gSLICr
  git pull
  mkdir -p build
  cd build
  cmake \
    -DOpenCV_DIR="${OpenCV_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDA_HOST_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -D_FORCE_INLINES" \
    ..
  make -j8
  cd ../..

  # Prepare MaskRCNN and data
  highlight "Building mask-rcnn with ms-coco..."
  git_clone "git clone --depth=1 https://github.com/matterport/Mask_RCNN.git"
  git_clone "git clone --depth=1 https://github.com/waleedka/coco.git"
  cd coco/PythonAPI
  make
  make install # Make sure to source the correct python environment first
  cd ../..
  cd Mask_RCNN
  mkdir -p data
  cd data
  wget --no-clobber https://github.com/matterport/Mask_RCNN/releases/download/v1.0/mask_rcnn_coco.h5
  cd ../..

  cd ..
fi # --build-dependencies

if [ -z "${BOOST_ROOT}" -a -d deps/boost ]; then
  BOOST_ROOT=$(pwd)/deps/boost
fi

# Build MaskFusion
highlight "Building MaskFusion..."
mkdir -p build
cd build
ln -s ../deps/Mask_RCNN ./ || true # Also, make sure that the file 'mask_rcnn_model.h5' is linked or present
cmake \
  -DBOOST_ROOT="${BOOST_ROOT}" \
  -DOpenCV_DIR="/usr/local/include/opencv" \
  -DPangolin_DIR="$(pwd)/../deps/Pangolin/build/src" \
  -DMASKFUSION_PYTHON_VE_PATH="/home/a/workspace/venv" \
  -DCUDA_HOST_COMPILER=/usr/bin/gcc \
  -DWITH_FREENECT2=OFF \
  ..
make -j8
cd ..
