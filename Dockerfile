FROM archlinux AS base

RUN : \
    && pacman --noconfirm -Syu --needed \
        vim nano tmux bash-completion file which \
        python python-pip git \
        base-devel gperftools \
    && pacman --noconfirm -Scc \
    && :

RUN : \
    && echo "set -g mouse on" > /etc/tmux.conf \
    && echo "set encoding=utf-8" > ~/.vimrc \
    && echo ". /usr/share/bash-completion/bash_completion" >> ~/.bashrc \
    && echo "export PS1='"'[txtgen-webui \h] \w \$ '"'" >> ~/.bashrc \
    && git config --global advice.detachedHead false \
    && :



FROM base AS rocm
# This stage adds ~22 GB of size
RUN : \
    && pacman --noconfirm -S rocm-hip-sdk \
    && pacman --noconfirm -Scc \
    && :

ENV PATH=/opt/rocm/bin:$PATH



FROM rocm AS webui

ENV HSA_OVERRIDE_GFX_VERSION=10.3.0
ENV HCC_AMDGPU_TARGET=gfx1030

ENV PIP_NO_CACHE_DIR=1

ARG WEBUI_DIR=/webui
ENV WEBUI_DIR="$WEBUI_DIR"
ARG GIT_WEBUI_HASH=b667ffa51d0e58508b0be74c1abea99d340a9ab8
RUN : \
    && git clone https://github.com/oobabooga/text-generation-webui $WEBUI_DIR \
    && cd $WEBUI_DIR \
    && git reset --hard $GIT_WEBUI_HASH \
    && python -m venv .venv \
    && source .venv/bin/activate \
    && pip install -U pip \
    && pip install build wheel \
    && mkdir repositories \
    && :

WORKDIR $WEBUI_DIR

ARG PYTORCH_ROCM_VERSION=5.4.2
RUN : \
    && source .venv/bin/activate \
    && pip install --index-url https://download.pytorch.org/whl/rocm${PYTORCH_ROCM_VERSION} \
        torch torchvision torchaudio \
    && :

ARG GIT_GPTQ_FOR_LLAMA_HASH=f12e3e2f913e88395e9209547d0955eb2f0edd84
RUN : \
    && cd repositories \
    && git clone https://github.com/WapaMario63/GPTQ-for-LLaMa-ROCm GPTQ-for-LLaMa \
    && cd GPTQ-for-LLaMa \
    && git reset --hard $GIT_GPTQ_FOR_LLAMA_HASH \
    && source $WEBUI_DIR/.venv/bin/activate \
    && python setup_rocm.py install \
    && :

RUN : \
    && source .venv/bin/activate \
    && pip install -r requirements.txt \
    && :

ARG GIT_BITSANDBYTES_HASH=8b1b1b429fc513fb1743d2efb81ff2ddfebdbc14
RUN : \
    && cd repositories \
    && git clone https://github.com/agrocylo/bitsandbytes-rocm \
    && cd bitsandbytes-rocm \
    && git reset --hard $GIT_BITSANDBYTES_HASH \
    && make hip -j \
    && source $WEBUI_DIR/.venv/bin/activate \
    && pip uninstall -y bitsandbytes \
    && python setup.py install \
    && :



FROM webui AS run

# Learned my lessons with stable diffusion
#   so will preload this for every torch app
ENV LD_PRELOAD=/usr/lib/libtcmalloc_minimal.so

ENV PORT=7860
CMD : \
    && source .venv/bin/activate \
    && python server.py --chat --api --verbose --wbits 4 --groupsize 128 --listen-port $PORT \
    && :
