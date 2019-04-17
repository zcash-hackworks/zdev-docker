# Zcash Docker Development Environment

**This is a work-in-progress and may not function reliably.**

This repository contains a Dockerfile that will help you get started building
Zcash's mobile app wallet stack. The projects' code is kept on your host
filesystem and shared into the docker container, so you can keep using the
editors and tools you're familiar with, and only use the container to run
builds. You can also run the `zcashd` and `lightwalletd` services within the
container.

The development environment currently supports building:

- `zcashd`
- `librustzcash` (preview branch)
- `lightwalletd` (preview branch)
- `zcash-android-wallet-sdk` (preview branch)

It does not yet support:

- `zcash-android-wallet-poc`

## Quick Start

**Requirements:** Docker, 30GB free disk space.

First, checkout this repository:

```
git checkout <this-repository's-url>
cd zdev-docker
```
Next, build the Docker image. This will create an image called `zdev` which
has all of the build dependencies pre-installed:

```
docker build -t zdev docker
```

Now, clone all of the projects you want to work on into the `mount/` directory:

```
cd mount
git clone git@github.com:zcash/zcash.git
git clone git@github.com:zcash-hackworks/lightwalletd.git
git clone git@github.com:str4d/librustzcash.git --branch preview
git clone git@github.com:zcash/zcash-android-wallet-sdk.git --branch preview
cd ..
```

You can now launch a new container instance of `zdev` and have access to your
clones of `zcash`, `lightwalletd`, etc. from within:

```
docker run -it --mount type=bind,source="$(pwd)"/mount,target=/mount zdev
```

The `./mount` directory will be shared between the host and the container,
accessible in the container at `/mount`. The changes you make to files inside
`/mount` in the container will change the files in `./mount`. **Docker
containers are ephemeral, so any changes you make to the container outside of
`/mount` will be lost.**

The previous command opened a shell inside the container. You can run build
commands, for example:

```
cd /mount/zcash
./zcutil/build.sh -j$(nproc)
./zcutil/fetch-params.sh
./qa/zcash/full-test-suite.py
```

See the individual projects' documentation for build instructions.

To open another shell into the running container, run `docker container ls`,
copy the container ID, and then run `docker exec -it <container ID> bash`.

To update the Ubuntu packages in the `zdev` image or make changes to which
dependencies are installed, edit the `docker/install-build-dependencies.sh`
script and then re-build the `zdev` image using the same command as above. The
changes will take effect in the next container instance you launch.

## Build Cheat Sheet

**Note:** All of the builds are independent for now, i.e. the build output of
`librustzcash` *doesn't* get used as an input to the `zcash-android-wallet-sdk`
build.

**`zcashd`**

```
cd /mount/zcash
./zcutil/build.sh -j$(nproc)
```

**`librustzcash`**

```
cd /mount/librustzcash
cargo build --release
```

**`lightwalletd`**

```
cd /mount/lightwalletd
go run cmd/injest/main.go <...>
go run cmd/server/main.go <...>
```

**`zcash-android-wallet-sdk`**

```
cd /mount/zcash-android-wallet-sdk
./gradlew clean assembleZcashtestnetRelease
```

## Running the Stack

TODO

## TODOs

- Put `.zcash-params` in the image.
- Put `.zcash-mainnet` and `.zcash-testnet` fully loaded into the image.
- Make the builds use the output of the dependency builds
- Instructions for starting/stopping the container
- Security review (are tools/code being downloaded safely? etc)
