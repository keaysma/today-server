FROM nimlang/nim:1.6.18

RUN apt-get update && \
    apt-get install -y libpq-dev

RUN touch .env

# Really wish I could find good docs on nimble
# RUN nimble install db_connector -y --nimbleDir:. # 2.x only
RUN nimble install dotenv -y --nimbleDir:.
RUN nimble install nimsha2 -y --nimbleDir:.

COPY main.nimble ./
COPY packages.json ./
COPY *nim ./
COPY routes/*nim ./routes/

# 2.x: --nimbleDir:./pkgs2
RUN nim c -d:release --NimblePath:./pkgs main.nim

EXPOSE 8080
ENTRYPOINT [ "./main" ]