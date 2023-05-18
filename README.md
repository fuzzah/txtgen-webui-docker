# txtgen-webui-docker
text-generation-webui in Docker for Linux & AMD GPUs<br>

So I needed to run [text-generation-webui](https://github.com/oobabooga/text-generation-webui) specifically in Docker on Arch Linux host with AMD Radeon RX 6700 XT, but failed to find complete solution on how to do it.<br>
This repo contains the Dockerfile with my findings.<br>

# Install
Prerequisites:
- Arch Linux, but other Linux-based systems are probably fine too
- Docker (`pacman -S docker docker-buildx ; sudo usermod -aG docker $USER`, restart current session by logging out and then logging in)
- AMD GPU (I have tested this only on RX 6700 XT)
- Not sure, but probably some video drivers installed on your host system (`pacman -S xf86-video-amdgpu`)
- A TON of disk space, like 40GB only for this image (without any models!). If you want to play with different models I suggest having ~150GB for this image + models, and the absolute minimum I think is somewhere at 60GB for image + one model.

Run the following commands:
```shell
git clone https://github.com/fuzzah/txtgen-webui-docker --depth=1
cd txtgen-webui-docker
docker build -t txtgen-webui .
```
The last command will probably take a lot of time.

# Run
You need to start the container and then run the Web UI.<br>

## Start or restart the container
To start the container use the following command:
```shell
docker run --rm -it --name txtgen-webui --network=host --device=/dev/kfd --device=/dev/dri --group-add=video --ipc=host --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v /mnt/extra/txtgen_webui_mnt/text-generation-webui/models:/webui/models txtgen-webui
```
It is advised for /mnt/extra to be mountpoint of some huge disk, as this is where the models will be saved.<br>

NOTE: if you plan to make changes in the container and restart it without recreating it every time you need it, omit the `--rm` option in the above command and at sequential runs use these commands instead:
```shell
docker container restart txtgen-webui
docker container attach txtgen-webui
```

## Use the Web UI
If you pass some command (e.g. bash) instead of default CMD instructions when issuing `docker run`, then you need to run these commands in the container to start the Web UI:
```shell
source .venv/bin/activate
python server.py --chat --wbits 4 --groupsize 128 --api --listen-port $PORT
```
In your browser visit this url to use the UI: http://127.0.0.1:7860.<br>
The default port number is 7860, but you can change it by passing the `PORT` env variable when starting the container, e.g. `docker run -e PORT=8080 ...`<br>

Get some quantized models from https://huggingface.co. You can fetch them either via the Web UI or using the download_model.py script.<br>

To gracefully stop the UI hit Ctrl+C in the container where the UI runs.<br>

# Credits / References / Sources / See also
These were the pieces of information I used to write the Dockerfile. If you struggle with using this repo, try checking the links for possible solutions and updates.<br>
Links:
- [the Web UI itself with general setup instructions](https://github.com/oobabooga/text-generation-webui)
- [an amazing article with setup instructions for Artix/Arch Linux & AMD GPUs](https://rentry.org/eq3hg) (no docker though)
- [bitsandbytes library with rocm support with build instructions for AMD GPUs](https://github.com/agrocylo/bitsandbytes-rocm/blob/8b1b1b429fc513fb1743d2efb81ff2ddfebdbc14/compile_from_source.md#rocm)
- [a great comment with setup instructions for Arch Linux](https://github.com/oobabooga/text-generation-webui/issues/879#issuecomment-1502144828) from [Nazushvel](https://github.com/Nazushvel)
- [the recommended way to run containers from the rocm/pytorch image](https://hub.docker.com/r/rocm/pytorch)

Mashed together in a working manner by [fuzzah](https://github.com/fuzzah).
