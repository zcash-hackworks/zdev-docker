# Zcash Docker Development Environment

🛑 **This is a work-in-progress and may not function reliably. It is certainly not
intended to be used in production.** 🛑

This repository contains a Dockerfile that will help you get started building
Zcash's mobile app wallet stack. The projects' code is kept on your host
filesystem and shared into the docker container, so you can keep using the
editors and tools you're familiar with, and only use the container to run
builds. You can also run the `zcashd` and `lightwalletd` services within the
container.

The development environment currently supports building:

- `zcashd`
- `librustzcash`
- `lightwalletd`
- `zcash-android-wallet-sdk` (preview branch)
- `zcash-android-wallet-poc`

## Quick Start

**Requirements:** Docker, KVM and a VNC client on the host (for the Android emulator), 30+GB free disk space.

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
git clone git@github.com:zcash/librustzcash.git
git clone git@github.com:zcash/zcash-android-wallet-sdk.git --branch preview
git clone git@github.com:zcash/zcash-android-wallet-poc.git
cd ..
```

You can now launch a new container instance of `zdev` and have access to your
clones of `zcash`, `lightwalletd`, etc. from within:

```
docker run -it --mount type=bind,source="$(pwd)"/mount,target=/mount -p 5901:5901 --privileged zdev
```

The `./mount` directory will be shared between the host and the container,
accessible in the container at `/mount`. The changes you make to files inside
`/mount` in the container will change the files in `./mount`. The `-p 5901:5901
--privileged` arguments are optional; they are required for running and
connecting to the Android emulator inside the container.

The previous command opened a shell inside the container. You can run build
commands, for example:

```
cd /mount/zcash
./zcutil/build.sh -j$(nproc)
./qa/zcash/full-test-suite.py
```

See the individual projects' documentation for build instructions.

To open another shell into the running container, run `docker container ls`,
copy the container ID, and then run `docker exec -it <container ID> bash`. You
can start and stop the container with `docker start` and `docker stop`.

To update the Ubuntu packages in the `zdev` image or make changes to which
dependencies are installed, edit the `docker/install-build-dependencies.sh`
script and then re-build the `zdev` image using the same command as above. The
changes will take effect in the next *new* container instance you launch. You
can of course also just make changes directly to the container instead of
updating the image every time.

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
go build -o server cmd/server/main.go
go build -o ingest cmd/ingest/main.go
```

**`zcash-android-wallet-sdk`**

```
cd /mount/zcash-android-wallet-sdk
./gradlew clean assembleZcashtestnetRelease
```

You can also build the `memo` sample app:

```
cd samples/memo
./gradlew :sdk:assemblezcashtestnetdebug :app:assembledebug
```

**`zcash-android-wallet-poc`**

First, generate a `google-services.json` file from [Google
Firebase](https://firebase.google.com/) and put it in
`zcash-android-wallet-poc/zcash-android-wallet-app/app/google-services.json`.
The `package_name` inside the file needs to be `cash.z.android.wallet.testnet`.

```
cd /mount/zcash-android-wallet-poc
cd zcash-android-wallet-app
./gradlew clean assembleZcashtestnetDebug
```

## Running the Stack

**This section assumes you've successfully run all of the builds in the Build
Cheat Sheet above.** We will set up:

1. A `zcashd` node connected to testnet.
2. A `lightwalletd` ingestor which receives blocks from the `zcashd` node.
3. A `lightwalletd` server which serves the blocks parsed by the ingestor to
   light clients.
4. A patched build of `zcash-android-wallet-poc` (the demo Android app), running
   in an emulator, connected to the `lightwalletd` server.

### Server-Side

**Note:** These instructions will need to be updated [once lightwalletd no
longer uses ZMQ to interact with
zcashd](https://github.com/zcash-hackworks/lightwalletd/pull/43)

First, start the `lightwalletd` ingestor:

```
cd /mount/lightwalletd
go run cmd/ingest/main.go -db-path database.db -log-file ingestor-log.txt
```

This will listen on port 28332 for a ZMQ connection from `zcashd`. Now put the
following contents in `/root/.zcash/zcash.conf`:

```
testnet=1
addnode=testnet.z.cash
zmqpubcheckedblock=tcp://127.0.0.1:28332
rpcuser=yourusername
rpcpassword=yourpassword
```

You're advised to change `yourusername` and `yourpassword` to something random.
This configures `zcashd` to sync with the testnet and send blocks to
`lightwalletd` on localhost port 28332. Now build and run `zcashd`:

```
cd /mount/zcash
./zcutil/build.sh -j$(nproc)
./zcutil/fetch-params.sh
./src/zcashd
```

If you check the contents of `/mount/lighwalletd/ingestor-log.txt`, you should
see that it is receiving blocks as the `zcashd` node syncs.

If you get an error message like `block -1: UNIQUE constraint failed` in the log
file, stop the ingestor, delete database.db, and then re-start it (the error
occurs when the ingestor is started before zcashd).

To serve these blocks to light clients, start the server:

```
cd /mount/lightwalletd
go run cmd/server/main.go -conf-file /root/.zcash/zcash.conf -db-path database.db -log-file server-log.txt
```
**Note:** If this command fails and there's an error message about database
locks in `server-log.txt` you need to stop the ingestor, start the server, then
re-start the ingestor.

After a while, `zcashd` will finish downloading all of the blocks, and as it
does so the ingestor will ingest them and the server will be able to serve them.
Once this is done, the mobile wallet will be able to connect and sync.

### Client-Side

First, we'll need to patch the demo app to be able to connect to our
`lightwalletd` server. Apply this patch:

```
diff --git a/zcash-android-wallet-app/app/src/main/java/cash/z/android/wallet/sample/SampleConfig.kt b/zcash-android-wallet-app/app/src/main/java/cash/z/android/wallet/sample/SampleConfig.kt
index 249da5c..d45c046 100644
--- a/zcash-android-wallet-app/app/src/main/java/cash/z/android/wallet/sample/SampleConfig.kt
+++ b/zcash-android-wallet-app/app/src/main/java/cash/z/android/wallet/sample/SampleConfig.kt
@@ -94,6 +94,7 @@ object MyWallet : WalletConfig {
 
 enum class Servers(val host: String, val displayName: String) {
     LOCALHOST("10.0.0.191", "Localhost"),
+    LOCALHOST2("10.0.2.2", "Localhost2"),
     //    WLAN("10.0.0.26"),
     WLAN1("10.0.2.24", "WLAN Conference"),
     WLAN2("192.168.1.235", "WLAN Office"),
diff --git a/zcash-android-wallet-app/app/src/main/res/values/strings.xml b/zcash-android-wallet-app/app/src/main/res/values/strings.xml
index a57ee92..560d204 100644
--- a/zcash-android-wallet-app/app/src/main/res/values/strings.xml
+++ b/zcash-android-wallet-app/app/src/main/res/values/strings.xml
@@ -108,6 +108,7 @@
         <item>WLAN Office</item>
         <item>WLAN Conference</item>
         <item>Localhost</item>
+        <item>Localhost2</item>
         <item>Custom...</item>
     </string-array>
 </resources>
```

Now rebuild the APK:

```
./gradlew clean assembleZcashtestnetDebug
```

To run the app in the Android emulator, first start a VNC server for the
emulator to use to serve its display:

```
vncserver :1 -geometry 1080x1920 -depth 24
```

This will output a message along the lines of:

```
...
New 'X' desktop is 3fe5a1e534df:1
...
```

Copy the `3fe...4df` part of your output and use it to replace the `fff...fff`
in the following command to start the emulator:

```
DISPLAY=ffffffffffff:1 $ANDROID_HOME/emulator/emulator -avd zemu -noaudio -no-boot-anim -gpu off -qemu
```

You can now install the APK in the emulator:

```
cd /mount/zcash-android-wallet-poc
$ANDROID_HOME/platform-tools/adb install ./zcash-android-wallet-app/app/build/outputs/apk/zcashtestnet/debug/app-zcashtestnet-debug.apk
```

From your *host* system, connect to the emulator with any VNC client, e.g...

```
vncviewer localhost:5901
```

You should now be able to control the emulated device and launch the app. To
connect to your `lightwalletd`, go in the app's settings and choose Localhost2,
click the checkmark, then re-open the app.

## TODOs

- Fix the VNC resolution
- How to do a reindex to fix the database?
- Put `.zcash-mainnet` and `.zcash-testnet` fully loaded into the image.
- Make the builds use the output of dependencies' builds
- Verify the "running the stack" instructions are actually correct.
- Security review (are tools/code being downloaded safely? what are the
  consequences of using a privileged docker? etc)
