# syntax=docker/dockerfile:latest

FROM ubuntu:latest

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN <<-EOF
	set -ex
	echo "::group::Preparing system"
	apt update -y && apt upgrade -y
	apt install -y curl unzip
	echo "::endgroup::"
	echo "::group::Installing Pandoc"
	apt install -y pandoc python3 python3-pandocfilters
	update-alternatives --install /usr/bin/python python /usr/bin/python3 1
	echo "::endgroup::"
	echo "::group::Installing TeX Live"
	apt install -y texlive-full
	echo "::endgroup::"
	echo "::group::Installing fonts"
	echo msttcorefonts msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
	apt install -y msttcorefonts fonts-noto fonts-noto-cjk
	curl -fsSL 'https://www.freebestfonts.com/download?fn=17501' -o /tmp/david-libre.zip
	unzip /tmp/david-libre.zip -d /usr/share/fonts
	echo "::endgroup::"
EOF
