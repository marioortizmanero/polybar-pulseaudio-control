FROM debian

RUN apt-get update && apt-get -y install bats pulseaudio psmisc procps

COPY ./pulseaudio-control.bash ./tests.bats /
