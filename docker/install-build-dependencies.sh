#!/bin/bash
set -e
cd /root/docker

# Dependencies for zcashd
# =================================================
apt-get install -y \
    build-essential pkg-config libc6-dev m4 g++-multilib \
    autoconf libtool ncurses-dev unzip git python python-zmq \
    zlib1g-dev wget curl bsdmainutils automake
apt-get install -y python-pip
pip install pyblake2

# Dependencies for lightwalletd
# =================================================
apt-get install -y libzmq3-dev

# Golang
wget https://dl.google.com/go/go1.12.4.linux-amd64.tar.gz -O go.tar.gz
tar xvf go.tar.gz
mv go /usr/local/
rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> /root/.bashrc
echo 'export PATH=/usr/local/go/bin:$PATH' >> /root/.bashrc

# Dependencies for librustzcash & Android rust build
# =================================================

# Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
echo 'export PATH=/root/.cargo/bin:$PATH' >> /root/.bashrc
export PATH=/root/.cargo/bin:$PATH

# Fixes "can't find crate for 'core'" build errors in zcash-android-wallet-sdk
rustup target add armv7-linux-androideabi
rustup target add aarch64-linux-android
rustup target add i686-linux-android

# Dependencies for zcash-android-wallet-sdk
# =================================================

# JDK
apt-get install -y zsh openjdk-8-jdk cmake

# Android SDK
# Credit: https://medium.com/@AndreSand/building-android-with-docker-8dbf717f54d4
ANDROID_HOME=/usr/local/android-sdk
echo 'export ANDROID_SDK_ROOT=/usr/local/android-sdk' >> /root/.bashrc
echo 'export ANDROID_HOME=/usr/local/android-sdk' >> /root/.bashrc
mkdir /root/.android
mkdir -p "$ANDROID_HOME"
cd "$ANDROID_HOME"
wget https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk.zip
unzip android-sdk.zip
rm android-sdk.zip
mkdir "$ANDROID_HOME/licenses"
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_HOME/licenses/android-sdk-license"
ls -la "$ANDROID_HOME"

# Accept licenses
yes | "$ANDROID_HOME/tools/bin/sdkmanager" --licenses

# Android NDK
"$ANDROID_HOME/tools/bin/sdkmanager" "ndk-bundle"

# Android Emulator
===================================================

$ANDROID_HOME/tools/bin/sdkmanager "platform-tools" "platforms;android-24" "emulator"
$ANDROID_HOME/tools/bin/sdkmanager "system-images;android-24;default;x86"
yes no | head -n 1 | $ANDROID_HOME/tools/bin/avdmanager create avd -n zemu -k "system-images;android-24;default;x86"
apt-get install -y tightvncserver
echo 'export USER=root' >> /root/.bashrc
