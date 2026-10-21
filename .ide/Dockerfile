# .ide/Dockerfile
FROM cnbcool/default-dev-env:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc libc6-dev libssl-dev strace python3 openssl ca-certificates \
      curl docker.io \
    && rm -rf /var/lib/apt/lists/*

# MoonBit 工具链（国内镜像），顺手验一次版本，装失败就直接让 build 挂掉。
RUN curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash \
     && "$HOME/.moon/bin/moon" version \
     && code-server --install-extension moonbit.moonbit-lang

RUN curl -fsSL https://downloads.claude.ai/claude-code-releases/bootstrap.sh | bash

RUN curl -fsSL https://github.com/SaladDay/cc-switch-cli/releases/latest/download/install.sh | bash

ENV PATH="$PATH:/root/.local/bin:/root/.moon/bin"

ENV workspace="/workspace"

RUN code-server --install-extension tamasfe.even-better-toml \
     && code-server --install-extension usernamehw.errorlens \
     && code-server --install-extension chanhx.crabviz \
     && code-server --install-extension Anthropic.claude-code
