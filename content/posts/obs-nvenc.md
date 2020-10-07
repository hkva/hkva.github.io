---
title: "Running OBS Studio with NVENC Support on Linux"
date: 2020-10-07T14:00:54-05:00
draft: true
---

![Scream Fortress banner](/obs-nvenc/sf.jpeg)

So, Team Fortress 2's annual [Scream Fortress](https://wiki.teamfortress.com/wiki/Halloween_event) event was released
again. If you haven't played it, all you need to know is that it's a fun time. There are exclusive items, contracts,
bosses, crazy spells, and lots and lots of critical hits. Usually, I like to record some of this insanity and share it
with my friends.

On Windows 10, there's a feature called "Windows Game DVR" that allows you to record the last X seconds of game play and
save it as a video file. This time around, I'm on Linux, where no such option exists. The closest thing for us poor, sad 
Linux users is [OBS](https://obsproject.com/), which has a "replay buffer" feature that can be used to save game clips
in a similar manner.

## Why

![htop with software encoding](/obs-nvenc/htop-software.png)

By default, OBS uses software x264 encoding. Because I want OBS to run in the background while playing games, I would like
it to use the GPU-accelerated Nvidia NVENC encoder, which would lessen the CPU load.

Under the hood, OBS uses [libav](https://libav.org/) for encoding. libav is built as part of the FFmpeg project, so we'll
need to build a custom version of FFmpeg with NVENC encoding enabled. Fortunately, thanks to the powers of
[dynamic linking](https://en.wikipedia.org/wiki/Dynamic_linker), we won't need to build OBS. We'll just ask the linker to
load *our* version of libav instead of the version installed via `apt-get`.

## Prerequisites 
Aside from the mostly-standard packages (`git`, `build-essential`, etc.), you'll need to install the dependencies for
building FFmpeg: https://trac.ffmpeg.org/wiki/CompilationGuide.

Note: Our FFmpeg build will not require `libaom` or `libsvtav1`.

Once you have the required packages installed, move to the folder where you want to build and install FFmpeg:
```shell
sudo mkdir /opt/obs-nvenc
sudo chown -R $USER:$USER /opt/obs-nvenc
cd /opt/obs-nvenc
```

## Step 1. Installing ffnvcodec
First, we need to install FFmpeg's loader for Nvidia-related libraries.

More info: https://trac.ffmpeg.org/wiki/HWAccelIntro
```shell
# Download the headers
git clone --depth 1 https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
# Install the headers to the system-wide include directory
sudo make -C nv-codec-headers install
```

## Step 2. Building FFmpeg/libav
Next, we'll build our own version of FFmpeg and install it to `/opt/obs-nvenc/ffmpeg-build`.
```shell
# Set output folder
export FF_OUT="/opt/obs-nvenc/ffmpeg-build"
# Download ffmpeg
git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
cd ffmpeg
# Configure FFmpeg
PATH="$FF_OUT/bin:$PATH" && \
PKG_CONFIG_PATH="$FF_OUT/lib/pkgconfig" && \
./configure \
	--prefix="$FF_OUT" \
	--extra-cflags="-I$FF_OUT/include" \
	--extra-ldflags="-L$FF_OUT/lib" \
	--bindir="$FF_OUT/bin" \
	--enable-shared \
	--enable-gpl \
	--enable-nonfree \
	--enable-gnutls \
	--enable-libass \
	--enable-libfdk-aac \
	--enable-libfreetype \
	--enable-libmp3lame \
	--enable-libopus \
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libx264 \
	--enable-libx265 \
	--enable-nvenc
# Compile FFmpeg (this may take a while)
make -j$(nproc)
# Copy to ffmpeg-build
make install
cd ..
```
Now confirm that our FFmpeg build has NVENC support:
```shell
LD_LIBRARY_PATH="/opt/obs-nvenc/ffmpeg_build/lib:$LD_LIBRARY_PATH" /opt/obs-nvenc/ffmpeg_build/bin/ffmpeg  -codecs | grep nvenc
```
```shell
ffmpeg version git-2020-10-07-1249698 Copyright (c) 2000-2020 the FFmpeg developers
  built with gcc 8 (Debian 8.3.0-6)
  configuration: --prefix=/opt/obs-nvenc/ffmpeg_build --extra-cflags=-I/opt/obs-nvenc/ffmpeg_build/include --extra-ldflags=-L/opt/obs-nvenc/ffmpeg_build/lib --bindir=/opt/obs-nvenc/ffmpeg_build/bin --enable-shared --enable-gpl --enable-nonfree --enable-gnutls --enable-libass --enable-libfdk-aac --enable-libfreetype --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-nvenc
  libavutil      56. 60.100 / 56. 60.100
  libavcodec     58.110.100 / 58.110.100
  libavformat    58. 61.100 / 58. 61.100
  libavdevice    58. 11.102 / 58. 11.102
  libavfilter     7. 87.100 /  7. 87.100
  libswscale      5.  8.100 /  5.  8.100
  libswresample   3.  8.100 /  3.  8.100
  libpostproc    55.  8.100 / 55.  8.100
 DEV.LS h264                 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10 (decoders: h264 h264_v4l2m2m h264_cuvid ) (encoders: libx264 libx264rgb h264_nvenc h264_v4l2m2m h264_vaapi nvenc nvenc_h264 )
 DEV.L. hevc                 H.265 / HEVC (High Efficiency Video Coding) (decoders: hevc hevc_v4l2m2m hevc_cuvid ) (encoders: libx265 nvenc_hevc hevc_nvenc hevc_v4l2m2m hevc_vaapi )
```

## Step 3. Launching OBS with our custom libav version
We can see which versions of libav OBS is using with the following command:
```shell
ldd $(which obs) | grep libav
```
```shell
libavcodec.so.58 => /lib/x86_64-linux-gnu/libavcodec.so.58 (0x00007fc7e2255000)
libavutil.so.56 => /lib/x86_64-linux-gnu/libavutil.so.56 (0x00007fc7e21d5000)
libavformat.so.58 => /lib/x86_64-linux-gnu/libavformat.so.58 (0x00007fc7e1f70000)
```
We can set `LD_LIBRARY_PATH` to tell Linux where to look for these libraries.
```shell
LD_LIBRARY_PATH="/opt/obs-nvenc/ffmpeg-build/lib:$LD_LIBRARY_PATH" ldd $(which obs) | grep libav
```
```shell
libavcodec.so.58 => /opt/obs-nvenc/ffmpeg-build/lib/libavcodec.so.58 (0x00007fa2f99c5000)
libavutil.so.56 => /opt/obs-nvenc/ffmpeg-build/lib/libavutil.so.56 (0x00007fa2f9715000)
libavformat.so.58 => /opt/obs-nvenc/ffmpeg-build/lib/libavformat.so.58 (0x00007fa2f94b8000)
```
Now, to launch OBS:
```shell
LD_LIBRARY_PATH="/opt/obs-nvenc/ffmpeg-build/lib:$LD_LIBRARY_PATH" obs
```
And for convenience, add the following to `~/.bashrc`:
```shell
alias obs-nvenc="LD_LIBRARY_PATH=\"/opt/obs-nvenc/ffmpeg-build/lib:$LD_LIBRARY_PATH\" obs"
```

## Result

![htop with NVENC encoding](/obs-nvenc/htop-nvenc.png)

OBS now runs with about 1/3rd of the CPU usage - perfect for running in the background.

If you happen to come across this guide and are running into issues, PLEASE LET ME KNOW! Create an issue [on GitHub](https://github.com/hkva/hkva.net/) or message me on Discord: `hkva#2413`
