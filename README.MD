# ioquake3 universal binaries
This project aims to create universal binaries for ioquake3 dedicated server, allowing you to turn any device with a
general-purpose processor into a Quake 3 Arena dedicated server. 

## Where the binaries at?
Executable binaries can be grabbed from:
- [GitLab Package Registry][0]
- [GitHub Releases][1]

The Docker images are available at:
- [GitLab Container Registry][2]

The distribution includes *only* the server binary. To obtain the Quake 3 Arena .pk3 files necessary to run the server,
you must purchase a legitimate copy of Quake 3 Arena. You can do so in places such as:
- [Steam][5]
- [GOG][6]
- [eBay (used physical copy; make sure it's authentic, however)][7]
- perhaps other videogame retailers

Whatever you do, avoid key resellers. They are more likely to scam you than provide you with a legitimate, working
copy.

If you happen to own an old copy, make sure it's updated to Point Release 1.32c:
- [Point Release 1.32][8]
- [Point Release 1.32c][9]

# Distributions
## Docker image
The image contains a statically-linked version of the ioquake3 dedicated server. The following platforms are supported:
- x86 (i386) - old PCs
- x86-64 (AMD64) - modern PCs
- AArch64 (ARM64, ARMv8) - modern SBCs like Raspberry Pi 4, modern smartphones, modern routers
- ARMv7 - older SBCs like Raspberry Pi 2, old smartphones, older routers
- ARMv6 - very old SBCs like Raspberry Pi 1, very old smartphones, very old routers
- PowerPC 64 little-endian (PPC64le) - IBM POWER-based computers, old gaming consoles
- S/390 (s390x) - IBM Z-based mainframes
- RISC-V64 (riscv64) - uh... yes. but look on the bright side: it can host a Quake 3 Arena server now!

I can make an attempt to provide images for other architectures, provided LLVM has a compiler toolchain available for
the target platform. If you have any requests, let me know via issues, or make a merge request!

The image is distroless, and contains only the statically-linked binary of the dedicated server. As such, no shell is
available inside.

The image tag is: `gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-universal:latest`

Image requires having access to original `pak*.pk3` files from Quake 3 Arena 1.32 point release. The directory
containing them will have to be mounted to the container at `/quake/baseq3`. You will also have to create a writable
directory, owned by uid 666/gid 666 to mount at `/quake/home`. These can be created with the following command:
`mkdir -p baseq3 home && sudo chown -R 666:666 home`

Assuming your `.pk3` files are placed in a `baseq3` directory in the current working directory, and you have a `home`
directory with the required permissions, the fastest way to get a server running is via the following command:

```
docker run -it --read-only \
  --mount type=bind,src=./baseq3,dst=/quake/baseq3,readonly \
  --mount type=bind,src=./home,dst=/quake/home \
  -p 27960:27960/udp \
  --name=quake3 \
  gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-universal:latest
```

You will need to make sure that UDP port 27960 is accessible for both incoming and outgoing traffic on the host.

**NOTE:** Docker Desktop for Windows introduces networking issues, which make it impossible to connect to a server
hosted under it. As such, it is recommended you install Docker (but not Docker Desktop) in a VM or WSL, and run it in
that, or host the container on another machine altogether.

You can also use a specific version instead of `latest`, these are available under `ci-NNNNN`, e.g. `ci-00007`.

Note that by default the server will not be playable, you need to at least load a map. For details, see section below.
In case of inputting commands to the server's console, you must omit `+set`.

## Static binaries
In addition to Docker images, the CI process now spits out static binaries (found under Deploy > Package Registry) for
all supported architecture. These binaries are statically-linked against musl libc using Clang, LLVM, and LLD. These
binaries are standalone insofar as additional binaries and libraries go. The `.pk3` files required for the server to run
must still be supplied separately.

The binaries come in 2 flavours, stripped and non-stripped. The former have all unnecessary data (such as debugging
information) removed, making the binaries smaller. There is, however, no performance impact to this.

To run the server, create a directory named `baseq3` where the server binary is created, and put your `.pk3` files in
it. Create a folder for the server to store its configuration in, and make sure the user which the server will run as
can write to it (typically you want permissions to be 700 or 755, with owner being the user). To run the server, you
need to specify several arguments on the command line:

`./ioq3ded-static +set dedicated 1 +set sv_allowDownload 0 +set com_hunkmegs 64 +set com_homepath /path/to/the/config/dir`

In this state, the server will not be playable. You need to at least load a map (`+set map q3dm7`). If you wish to
enable bots, you can additionally specify `+set bot_enable 1 +set g_spskill 2 +set bot_minplayers 4` (replace 4 with the
desired minimum total number of players). Every actual player joining will replace 1 bot, so specifying 4 means that if
2 players join, only 2 bots will remain. `g_spskill` controls bot difficulty level: 2 is default, 0 is easiest, 5 is
hardest. Further command and variable documentation can be found [here][4].

## MikroTik-compatible container image
Due to the tiny footprint of this image (generally <32MiB RAM usage), it is possible to host a Quake 3 Arena server on a
sufficiently powerful Mikrotik router. For more information on how to use containers on RouterOS 7,
[see RouterOS documentation][3]. It is **strongly recommended** to
use USB storage, as containers might wear down your devices internal storage very fast.

It should be noted that only ARM- and ARM64-based routers, and CHR instances can run this image, due to architecture
support. To find out which architecture your router is based on, log in via WinBox or CLI, and run
`/system/resource/print` (or find analogous option in WinBox), and look for `cpu:` section.

Because MikroTik's container implementation doesn't handle distroless containers at all, a special Alpine Linux-based
image set was prepared for this purpose, under the tag of
`gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-mikrotik:latest`.

First step is preparing mounts. You will need 2 of them. In CLI, these can be set up via:

```
/container/mounts/
add name=quake3-baseq3 dst=/home/quake3/ioq3/baseq3 src=/local/path/to/baseq3
add name=quake3-home dst=/home/quake3/.q3a src=/local/path/to/quake-home
```

Next you will have to import the image to the router. On a PC with docker, do the following, depending on router's
architecture:
- CHR (x64): `docker pull --platform=linux/amd64 gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-mikrotik:latest`
- ARM: `docker pull --platform=linux/arm/v7 gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-mikrotik:latest`
- ARM64/CHR (AMPERE): `docker pull --platform=linux/arm64/v8 gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-mikrotik:latest`

In all below commands you have substitute provided paths and addresses with ones appropriate to your environment.

Next step is exporting the image:
`docker save gl-registry.emzi0767.dev/emzi0767/ioq3-universal/ioq3-mikrotik:latest -o quake3.tar`. You will have to
transfer this file to the router. The easiest method is SCP, if you have FTP set up:
`scp quake3.tar admin@192.168.88.1:/path/to/images/quake3.tar`.

Once transferred, you will need to create a VETH interface on the router, and set up the container:

```
/interface/veth/add name=veth-quake \
  address=container_ip \
  gateway=container_gateway
/container/add file=/path/to/images/quake3.tar \
  interface=veth-quake \
  root-dir=/path/to/containers/quake3 \
  mounts=quake3-baseq3,quake3-home \
  logging=yes
```

This will create a container in a stopped state. You can start it now, this will cause it to error out but it will
create necessary directories. Final step is to transfer your `.pk3` files to the router. This can, again, be easily done
with scp: `scp pak*.pk3 admin@192.168.88.1:/local/path/to/baseq3`. Once this is done, you can restart the container and
it should work this time. Note that this will not do much at this stage. To actually launch a game, load maps, spawn
bots, etc., you will need to find a way to edit configs stored in the `quake3-home` mount for the server, or you will
have to specify those options via `cmd=` parameter to `/container/add` (e.g.
`cmd="+set bot_enable 1 +set g_spskill 2 +set bot_minplayers 4 +map q3dm7"`). Currently it is not possible to interact
with stdin of a container running on a Mikrotik, so you should also enable rcon if you want to manage the server without
restarting it. For more command info, see static binary section.

# So why did I do this?
Ever had an old computer and nothing to do with it? Well, in my case, the motivator was seeing if my Mikrotik hAP ac²
router, which has 128MB of RAM, could host a game. But since I was creating a build setup for a rather old CPU
architecture, why not include other old and/or exotic architectures while at it?


[0]: https://gitlab.emzi0767.dev/Emzi0767/ioq3-universal/-/packages
[1]: https://github.com/Emzi0767/ioq3-universal/releases
[2]: https://gitlab.emzi0767.dev/Emzi0767/ioq3-universal/container_registry
[3]: https://help.mikrotik.com/docs/display/ROS/Container
[4]: http://www.joz3d.net/html/q3console.html
[5]: https://store.steampowered.com/app/2200/Quake_III_Arena/
[6]: https://www.gog.com/en/game/quake_iii_arena
[7]: https://www.ebay.com/sch/i.html?_nkw=quake+3+arena+pc
[8]: https://www.moddb.com/games/quake-iii-arena/downloads/quake-iii-arena-point-release-132-pc
[9]: https://www.moddb.com/games/quake-iii-arena/downloads/quake-iii-arena-point-release-132-to-132c-pc
