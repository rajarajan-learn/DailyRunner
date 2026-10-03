FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates curl less \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

USER node
WORKDIR /workspace
ENTRYPOINT ["claude"]
