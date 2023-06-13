FROM archlinux AS base

RUN : \
    && pacman --noconfirm -Syu --needed \
        vim nano tmux bash-completion file which \
        python python-pip git \
        base-devel gperftools \
    && pacman --noconfirm -Scc \
    && :

ENV LANG=en_US.UTF-8

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



FROM rocm AS webui-deps
ENV PIP_NO_CACHE_DIR=1

ARG VENV_PATH=/venv
ENV VENV_PATH=$VENV_PATH
RUN : \
    && python -m venv "$VENV_PATH" \
    && source "$VENV_PATH/bin/activate" \
    && pip install -U pip \
    && pip install build wheel \
    && :


ARG PYTORCH_ROCM_VERSION=5.4.2
RUN : \
    && source "$VENV_PATH/bin/activate" \
    && pip install --index-url https://download.pytorch.org/whl/rocm${PYTORCH_ROCM_VERSION} \
        torch torchvision torchaudio \
    && :


ARG REPOS_PATH=/repositories
ENV REPOS_PATH=$REPOS_PATH
WORKDIR $REPOS_PATH

ARG HSA_OVERRIDE_GFX_VERSION=10.3.0
ARG HCC_AMDGPU_TARGET=gfx1030

ENV HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION
ENV HCC_AMDGPU_TARGET=$HCC_AMDGPU_TARGET

# bitsandbytes-rocm: build, but don't install yet.
# Otherwise, webui requirements will overwrite it.
ARG GIT_BITSANDBYTES_HASH=8b1b1b429fc513fb1743d2efb81ff2ddfebdbc14
ARG BITSANDBYTES_DIR_NAME=bitsandbytes-rocm
RUN : \
    && git clone https://github.com/agrocylo/bitsandbytes-rocm "$BITSANDBYTES_DIR_NAME" \
    && cd "$BITSANDBYTES_DIR_NAME" \
    && git reset --hard $GIT_BITSANDBYTES_HASH \
    && make hip -j \
    && :


ARG GIT_GPTQ_FOR_LLAMA_HASH=f12e3e2f913e88395e9209547d0955eb2f0edd84
RUN : \
    && git clone https://github.com/WapaMario63/GPTQ-for-LLaMa-ROCm GPTQ-for-LLaMa \
    && cd GPTQ-for-LLaMa \
    && git reset --hard $GIT_GPTQ_FOR_LLAMA_HASH \
    && source "$VENV_PATH/bin/activate" \
    && python setup_rocm.py install \
    && :



FROM webui-deps AS webui
ARG WEBUI_PATH=/webui
ENV WEBUI_PATH=$WEBUI_PATH
WORKDIR $WEBUI_PATH

ARG GIT_WEBUI_HASH=8936160e54d0884494fe0735dee14304c4b4fbbb
RUN : \
    && git clone https://github.com/oobabooga/text-generation-webui "$WEBUI_PATH" \
    && cd "$WEBUI_PATH" \
    && git reset --hard $GIT_WEBUI_HASH \
    && ln -s "$REPOS_PATH" "$WEBUI_PATH/repositories" \
    && source "$VENV_PATH/bin/activate" \
    && AGPTQ_URL=$(grep -E requirements.txt -e 'AutoGPTQ/releases.*?Linux' | cut -d ';' -f 1) \
    && AGPTQ_VER=$(echo "$AGPTQ_URL" | sed -r 's|^.*?/auto_gptq-(.*?\+cu[^-]*).*$|\1|g') \
    && curl -L -o "auto_gptq-${AGPTQ_VER}-py3-none-any.whl" "$AGPTQ_URL" \
    && pip install ./auto_gptq*.whl \
    && rm -f ./auto_gptq*.whl \
    && sed -i requirements.txt -e '/auto_gptq.*\.whl/d' \
    && pip install -r requirements.txt \
    && pip uninstall -y bitsandbytes \
    && cd "$REPOS_PATH/$BITSANDBYTES_DIR_NAME" \
    && python setup.py install \
    && :



FROM webui AS run

# Learned my lessons with stable diffusion
#   so will preload this for every torch app
ENV LD_PRELOAD=/usr/lib/libtcmalloc_minimal.so

ENV PORT=7860
CMD : \
    && source "$VENV_PATH/bin/activate" \
    && python server.py \
        --wbits 4 --groupsize 128 \
        --chat \
        --api \
        --verbose \
        --listen-port $PORT \
    && :
