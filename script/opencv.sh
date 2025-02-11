#!/bin/bash
BBlue='\033[1;34m'
BGreen='\033[1;32m'
BRed='\033[1;31m'
NC='\033[0m'
opencvLink="https://github.com/opencv/opencv.git"
contribLink="https://github.com/opencv/opencv_contrib.git"
installCuda=0

export_bashrc () {
    if ! grep -Fxq "$1" $HOME/.bashrc; then
        echo $1 >> $HOME/.bashrc
    fi
}

# Check Sudo bash
if [[ "$SUDO_USER" == "" ]]; then
    echo -e "${BRed}Use 'sudo bash' before executing this script!${NC}"
    exit 1
fi
pip3 uninstall opencv_python

# Install folder
installDir="$HOME/Libraries"
mkdir -p $installDir && cd $installDir
echo -e "OpenCV will be install in \"$PWD\""
sleep 2

# Use OpenCV with Cuda support
while : ; do
    read -p "$(echo -e $BBlue"Do you want install OpenCV with CUDA support? (y\\\n): $NC")" A
    A=${A^^}
    if [[ "$A" == "Y" || "$A" == "YES" ]]; then
        # Check Nvidia driver installed
        nvidiaCheck="$(lsmod | grep ^nvidia | awk {'print $1'})"
        if [[ "$nvidiaCheck" ==  *"nvidia"* ]]; then
            echo -e "Nvidia driver installed!"    
        else
            echo -e "${BRed}Error: System has not installed nvidia-driver yet!${NC}"
            exit 1
        fi
        # Check Cuda
        cudaCheck=$(find /usr/local/cuda-*   -maxdepth 0)
        if [[ "$cudaCheck" == "" ]]; then            
            echo -e "${BRed}Error: Cuda not installed!${NC}"
            exit 1
        else
            cudaVer=$(nvcc -V | sed -n 4p | cut -d" " -f5)
            cudaVer=${cudaVer:0:4}
            if [[ "$cudaVer" == "" ]]; then
               for i in $cudaCheck; do
                    if [ -d "$i/bin" ] & [ -d "$i/lib64" ]; then
                        export_bashrc "# Cuda"
                        export_bashrc "export PATH=$i/bin\${PATH:+:\${PATH}}"
                        export_bashrc "export LD_LIBRARY_PATH=$i/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
                        export PATH=$i/bin${PATH:+:${PATH}}
                        export LD_LIBRARY_PATH=$i/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
                        cudaVer=$(nvcc -V | sed -n 4p | cut -d" " -f5)
                        cudaVer=${cudaVer:0:4}
                    else
                        echo -e "${BRed}Error: Cuda Install error at '$i'!${NC}"
                        sleep 2
                    fi
                done                
            fi
            echo -e "Found CUDA-$cudaVer"
            installCuda=1
        fi
        break
    elif [[ "$A" == "N" || "$A" == "NO" ]]; then
        echo -e "Install OpenCV without CUDA support" 
        break
    fi
done


# Select version
tags=$(git ls-remote --tags $opencvLink | sed 's/.*\///; s/\^{}//' | sort -u)
heads=$(git ls-remote --heads $opencvLink | sed 's/.*\///; s/\^{}//' | sort -u)
versions="$tags $heads"
readarray -d " " -t versionsArr <<< "$versions"
if [[ ${#versions} == 1 ]]; then
    echo -e "${BRed}Error: Cannot connect to $opencvLink!${NC}"
    exit 1
fi
installVersion=""
while : ; do
    read -p "$(echo -e $BBlue"Choose OpenCV Version
${NC}(Press ${BBlue}l${NC} to list all available tags)
(Press ${BBlue}Return/Enter${NC} to install master branch)${BBlue}: $NC")" A
    if [[ $A == "l" || $A == "L" ]]; then
        for ver in ${versionsArr[@]}; do
            echo -e "$ver"
        done
    else
        if [[ "$A" == "" ]]; then
            installVersion="master"
        fi
        for ver in ${versionsArr[@]}; do
            if  [[ "$ver" == "$A" ]]; then
                installVersion=$A
            fi
        done
        if [[ "$installVersion" != "" ]]; then

            break;
        else
            echo -e "Undefined version: \"$A\""
        fi
    fi
done
echo -e "Installing OpenCV_$installVersion ..."
installDir="$PWD/OpenCV_$installVersion" 
mkdir -p $installDir && cd $installDir
sleep 2

# Clone opencv and opencv_contrib repo
if ! [ -d opencv ]; then
    git clone $opencvLink
fi
if ! [ -d opencv_contrib ]; then
    git clone $contribLink
fi

if ! [ -d opencv ]; then
    echo -d "${BRed}Error: Could not clone opencv from \"$opencvLink\"${NC}"
    exit 1
fi
if ! [ -d opencv_contrib ]; then
    echo -d "${BRed}Error: Could not clone opencv_contrib from \"$contribLink\"${NC}"
    exit 1
fi
if [[ $installVersion == "master" ]]; then
    cd opencv
else
    cd opencv_contrib
    git checkout $installVersion
    cd ../opencv
    git checkout $installVersion
fi

# Install Addition Packages
sudo apt purge libopencv-dev libopencv-python libopencv-samples libopencv*

sudo apt-get install -y build-essential cmake git pkg-config libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
    libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev \
    gfortran openexr libatlas-base-dev python3-dev python3-numpy \
    libtbb2 libtbb-dev libdc1394-22-dev python3-pip

# Install
mkdir -p build && cd build
if [ -f "CMakeCache.txt" ]; then
    sudo rm CMakeCache.txt
fi
if [[ "installCuda" -eq 1 ]]; then
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D_GLIBCXX_USE_CXX11_ABI=0 \
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D BUILD_opencv_python2=OFF \
        -D PYTHON3_EXECUTABLE=$(which python3) \
        -D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -D PYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
        -D WITH_CUDA=ON \
        -D ENABLE_FAST_MATH=1 \
        -D CUDA_FAST_MATH=1 ..
else
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
        -D CMAKE_INSTALL_PREFIX=/usr/local \
        -D_GLIBCXX_USE_CXX11_ABI=0 \
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D BUILD_opencv_python2=OFF \
        -D PYTHON3_EXECUTABLE=$(which python3) \
        -D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -D PYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules ..
fi
sudo make -j$(($(nproc) - 1)) 
sudo make install

export_bashrc "# OpenCV"
export_bashrc "export LD_LIBRARY_PATH=$installDir/opencv/build/lib:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH=$installDir/opencv/build/lib:$LD_LIBRARY_PATH
python3 -c "import cv2; print(cv2.__version__)"
echo -e "${BGreen}Done!${NC}"