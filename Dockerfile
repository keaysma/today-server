FROM nimlang/nim

COPY *nim ./
COPY packages.json ./

RUN touch .env

RUN apt-get update && \
    apt-get install -y libpq-dev

# Really wish I could find good docs on nimble
RUN nimble install dotenv -y --nimbleDir:.
RUN nimble install nimsha2 -y --nimbleDir:.

RUN nim c -d:release --NimblePath:./pkgs main.nim

EXPOSE 8080
ENTRYPOINT [ "./main" ]