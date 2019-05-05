#! /bin/bash
# Steps needed to fetch and build ROS2 on Raspian (as of 20180820)
# Built from instructions at https://github.com/ros2/ros2/issues/418#issuecomment-351331918
#     merged with instructions at https://github.com/ros2/ros2/wiki/Linux-Development-Setup
# NOTE: there is an initial MANUAL STEP to increase swap space on the build
#      system so the compilation can complete.
#
# My process is to build ROS2 on one RaspberryPi3 then create a TAR file of the /opt/ros2
#     installed directory. This TAR file is copied to another RaspberryPi3 where I have just
#     done the "DoFetchBuildTools" step to get any needed OS packages.

# Script broken into pieces so one can adapt and debug.
# Change each of the section flags to either "yes" or "no".
DoIncreaseSwapSpace="no"    # MANUAL STEP
DoSetKeys="yes"             # Fetch ROS2 repository keys (only needs to happen once)
DoSetLocale="yes"           # Set locale environment (only needs to happen once)
DoFetchBuildTools="yes"     # Fetch all tools needed for building ROS2
DoFetchNewCMake="no"        # Fetch newer version of CMake (can fix some build errors)
DoFetchROS2Sources="yes"    # Fetch the ROS2 sources from Github
DoCleanFetchROS2Sources="no" # if set to 'yes', delete existing and fetch new, clean source tree
DoFetchROS2Dependencies="yes"   # Run rosdep to fetch and build dependencies
DoBuild="yes"               # Build ROS2
DoCreateTARFiles="yes"      # Create a TAR file of the installed ROS2

ROS2_DISTRO=crystal

# The state of tools that seem to work
# uname -a
#   Linux mbpi3 4.14.52-v7+ #1123 SMP Wed Jun 27 17:35:49 BST 2018 armv7l GNU/Linux
# lsb_release -a
#   Description:    Raspbian GNU/Linux 8.0 (jessie) Release:    8.0 Codename:   jessie
# gcc --version
#   gcc (Raspbian 6.3.0-18+rpi1+deb9u1) 6.3.0 20170516
# g++ --version
#   g++ (Raspbian 6.3.0-18+rpi1+deb9u1) 6.3.0 20170516
# cmake --version
#   cmake version 3.9.6

if [[ "$DoIncreaseSwapSpace" == "yes" ]] ; then
    echo "=== Doing manual step of increasing swap space for the ROS2 build"
    # Swap space on the SSD is a bad idea but it is only used for this build.
    # Manual steps:
    # edit /etc/dphys-swapfile
    # change "CONF_SWAPSIZE=100" to "CONF_SWAPSIZE=1000"
    # Remember to reboot so changes apply
fi

# Fetch the ROS2 repository keys and set up repository linkage.
if [[ "$DoSetKeys" == "yes" ]] ; then
    echo "=== Setting keys"
    sudo apt update && sudo apt install curl
    curl http://repo.ros2.org/repos.key | sudo apt-key add 

    echo "deb [arch=amd64,arm64] http://repo.ros2.org/ubuntu/main $(lsb_release -cs) main" > /tmp/frogfrogfrog
    sudo mv /tmp/frogfrogfrog /etc/apt/sources.list.d/ros2-latest.list
else
    echo "=== Not setting keys"
fi

# Set the locale information for what works with ROS
if [[ "$DoSetLocale" == "yes" ]] ; then
    echo "=== Initializing locale"
    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL-en_US.UTF-8 LANG=en_US.UTF-8
else
    echo "=== Not initializing locale"
fi
export LANG=en_US.UTF-8

# Fetch all the packages needed for building.
if [[ "$DoFetchBuildTools" == "yes" ]] ; then
    echo "=== Fetching build tools"
    sudo apt update && sudo apt install -y \
      build-essential \
      cmake \
      git \
      python3-colcon-common-extensions \
      python3-pip \
      python3-rosdep \
      python3-vcstool \
      curl \
      wget
    # install some pip packages needed for testing
    sudo -H python3 -m pip install -U \
      argcomplete \
      flake8 \
      flake8-blind-except \
      flake8-builtins \
      flake8-class-newline \
      flake8-comprehensions \
      flake8-deprecated \
      flake8-docstrings \
      flake8-import-order \
      flake8-quotes \
      pytest-repeat \
      pytest-rerunfailures
    # [Ubuntu 16.04] install extra packages not available or recent enough on Xenial
    python3 -m pip install -U \
      pytest \
      pytest-cov \
      pytest-runner \
      setuptools
    # install Fast-RTPS dependencies
    sudo apt install --no-install-recommends -y \
      libasio-dev \
      libtinyxml2-dev

    sudo apt install python3-argcomplete
else
    echo "=== Not fetching build tools"
fi

# A newer version of CMake might be needed for a successful build
#    (Some build failures were reported with the standard CMake)
if [[ "$DoFetchNewCMake" == "yes" ]] ; then
    echo "=== Fetching, building, and installing newer version of CMake"
    # ref: https://cmake.org/install/
    sudo apt-get remove -y cmake
    curl -O https://cmake.org/files/v3.12/cmake-3.12.1.tar.gz
    tar -xzf cmake-3.12.1.tar.gz
    cd cmake-3.12.1
    ./bootstrap
    make
    sudo make install
    sudo ln -s /usr/bin/cmake /usr/local/bin/cmake
fi

# Fetch ROS2 sources
if [[ "$DoFetchROS2Sources" == "yes" ]] ; then
    echo "=== Fetching ROS2 Sources"
    # set ROS_RELEASE to 'release-latest' for last release, or 'master' for the latest patches and tweeks
    # ROS_RELEASE=release-latest
    ROS_RELEASE=master
    mkdir -p ~/ros2_ws
    cd ~/ros2_ws
    if [[ "$DoCleanFetchROS2Sources" == "yes" || ! -e "src/ros2" ]] ; then
        # If forcing a clean fetch or 'src' directory doesn't exist, fetch the sources
        echo "===    Clean fetch of ROS2 Sources"
        rm -rf src
        rm -f ros2.repos
        wget https://raw.githubusercontent.com/ros2/ros2/${ROS_RELEASE}/ros2.repos
        mkdir src
        vcs import src < ros2.repos
    else
        # If sources already there, just pull latest version
        echo "===    'git pull' on existing ROS2 Sources"
        vcs pull src
    fi
else
    echo "=== Not fetching ROS2 Sources"
fi

# ROS2 dependencies fetched with 'rosdep'.
if [[ "$DoFetchROS2Dependencies" == "yes" ]] ; then
    echo "=== Fetching ROS2 dependencies"
    cd ~/ros2_ws
    # if it looks like 'init' has already been run, don't do that step
    if [[ ! -e "/etc/ros/rosdep/sources.list.d/20-default.list" ]] ; then
        sudo rosdep init
    fi
    rosdep update
    rosdep install --from-paths src --ignore-src --rosdistro $ROS2_DISTRO -y --skip-keys "console_bridge fastcdr fastrtps libopensplice67 rti-connext-dds-5.3.1 urdfdom_headers"
else
    echo "=== Not fetching ROS2 dependencies"
fi

# Built it.
if [[ "$DoBuild" == "yes" ]] ; then
    echo "=== Doing ROS2 build"
    cd ~/ros2_ws
    sudo colcon build --install-base /opt/ros2
else
    echo "=== Not doing ROS2 build"
fi

# Create compressed TAR files of all the built and installed code for distribution
if [[ "$DoCreateTARFiles" == "yes" ]] ; then
    echo "=== Creating TAR files"
    cd
    # tar -czf ros2_ws.tgz ros2_ws
    cd /opt
    tar -czf ~/opt_ros2.tgz ros2
else
    echo "=== Not creating TAR files"
fi

