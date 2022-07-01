FROM swift:5.6-focal

WORKDIR /build

RUN apt-get update && apt-get install libsqlite3-dev

ENV BM_DOCKER=1

COPY ./Package.* ./
RUN swift package resolve

COPY . .
RUN swift build -c release

WORKDIR /app

RUN yes | cp -f /build/.build/release/BotModrin .

CMD [ "./BotModrin" ]
