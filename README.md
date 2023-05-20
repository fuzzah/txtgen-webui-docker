# txtgen-webui-docker
So I needed to run [text-generation-webui](https://github.com/oobabooga/text-generation-webui) specifically in Docker on Arch Linux host with AMD Radeon RX 6700 XT, but failed to find complete solution on how to do it.<br>
This repo contains the [Dockerfile](Dockerfile) with my findings.<br>

# Install
Prerequisites:
- Arch Linux, but other Linux-based systems are probably fine too
- Docker (`pacman -S docker docker-buildx ; sudo usermod -aG docker $USER`, restart current session by logging out and then logging in)
- an AMD GPU (I have tested this only on RX 6700 XT)
- not sure, but probably some video drivers installed on your host system (`pacman -S xf86-video-amdgpu`)
- a TON of disk space, like 40GB only for this image (without any models!). If you want to play with different models I suggest having ~150GB for this image + models, and the absolute minimum I think is somewhere at 50GB for image + one model.

Run the following commands:
```shell
git clone https://github.com/fuzzah/txtgen-webui-docker --depth=1
cd txtgen-webui-docker
docker build -t txtgen-webui .
```
The last command will probably take a lot of time.

Overridable build args (use `--build-arg NAME=value` for each):
- `GIT_WEBUI_HASH`: commit hash or tag for [oobabooga/text-generation-webui](https://github.com/oobabooga/text-generation-webui)
- `GIT_GPTQ_FOR_LLAMA_HASH`: commit hash or tag for [WapaMario63/GPTQ-for-LLaMa-ROCm](https://github.com/WapaMario63/GPTQ-for-LLaMa-ROCm)
- `GIT_BITSANDBYTES_HASH`: commit hash or tag for [agrocylo/bitsandbytes-rocm](https://github.com/agrocylo/bitsandbytes-rocm)
- `PYTORCH_ROCM_VERSION`: PyTorch version to use. Used as part of URL for pip index to use, so the actual URL must exist, e.g. the value 5.4.2 is OK, because `https://download.pytorch.org/whl/rocm5.4.2` is an existing URL.
- `HSA_OVERRIDE_GFX_VERSION`, `HCC_AMDGPU_TARGET`: you may want to change these to match some AMD GPU other than RX 6700 XT. For specific values for your GPU please refer to the Internet.

# Run
You need to start the container and then run the Web UI script.<br>

## Start or restart the container
To start the container use the following command:
```shell
docker run --rm -it --name txtgen-webui --network=host --device=/dev/kfd --device=/dev/dri --group-add=video --ipc=host --cap-add=SYS_PTRACE --security-opt seccomp=unconfined -v /mnt/extra/txtgen-webui-models:/webui/models txtgen-webui
```
It is advised for /mnt/extra to be mountpoint of some huge disk, as this is where the models will be saved.<br>

NOTE: if you plan to make changes in the container and restart it without recreating it every time you need it, omit the `--rm` option in the above command and at sequential runs use these commands instead:
```shell
docker container restart txtgen-webui
docker container attach txtgen-webui
```

## Use the Web UI
If you run the container without a custom command or entrypoint, then the UI script will start automatically.<br>
However, If you pass some command (e.g. bash) instead of the default CMD instructions, then you need to run these commands in the container to start the Web UI:
```shell
source "$VENV_PATH/bin/activate"
python server.py --chat --api --verbose --wbits 4 --groupsize 128 --listen-port $PORT
```
In your browser visit this url to access the UI: http://127.0.0.1:7860.<br>
The default port number is 7860, but you can change it by passing the `PORT` env variable when starting the container, e.g. `docker run -e PORT=8080 ...`<br>

Get some quantized models from https://huggingface.co. You can fetch them either via the Web UI or using the download_model.py script.<br>

To gracefully stop the UI hit Ctrl+C in the container where the UI runs.<br>

# Credits / References / Sources / See also
These were the pieces of information I used to write the Dockerfile. If you struggle with using this repo, try checking the links for possible solutions and updates.<br>
Links:
- [the Web UI itself with general setup instructions](https://github.com/oobabooga/text-generation-webui) (has instructions and even some files for Docker, but only for CPU and Nvidia)
- [an amazing article with setup instructions for Artix/Arch Linux & AMD GPUs](https://rentry.org/eq3hg) (no docker though)
- [bitsandbytes library with rocm support with build instructions for AMD GPUs](https://github.com/agrocylo/bitsandbytes-rocm/blob/8b1b1b429fc513fb1743d2efb81ff2ddfebdbc14/compile_from_source.md#rocm) (but it actually has to be installed the last)
- [a great comment with setup instructions for Arch Linux](https://github.com/oobabooga/text-generation-webui/issues/879#issuecomment-1502144828) from [Nazushvel](https://github.com/Nazushvel) (but I had to change the proposed installation order)
- [the recommended way to run containers from the rocm/pytorch image](https://hub.docker.com/r/rocm/pytorch) (but I don't rely on rocm/pytorch image and instead build my own to save some disk space)

Mashed together in a working manner by [fuzzah](https://github.com/fuzzah).
