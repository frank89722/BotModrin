FROM swift:5.6-focal

WORKDIR /build

RUN apt-get update && apt-get install libsqlite3-dev

COPY ./Package.* ./
RUN swift package resolve

COPY . .

ENV BM_DOCKER=1

RUN swift build -c release

WORKDIR /app

RUN cp /build/.build/release/BotModrin .

CMD [ "./BotModrin" ]