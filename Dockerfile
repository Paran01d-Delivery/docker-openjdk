FROM dairyd/buildpack-deps:stretch-curl

LABEL maintainer="24.7@yungasdevops.com"

ENV REFRESHED_AT 2019-06-01

# A few reasons for installing distribution-provided OpenJDK:
#
#  1. Oracle.  Licensing prevents us from redistributing the official JDK.
#
#  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
#     really hairy.
#
#     For some sample build times, see Debian's buildd logs:
#       https://buildd.debian.org/status/logs.php?pkg=openjdk-8

RUN apt-get update && apt-get install -y --no-install-recommends \
		bzip2 \
		unzip \
		xz-utils \
	&& rm -rf /var/lib/apt/lists/*

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

ENV DEBIAN_FRONTEND noninteractive

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home

# do some fancy footwork to create a JAVA_HOME that's cross-architecture-safe
RUN ln -svT "/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)" /docker-java-home
ENV JAVA_HOME /docker-java-home/jre

ENV JAVA_VERSION 8u151
ENV JAVA_DEBIAN_VERSION 8u151-b12-1~deb9u1

# see https://bugs.debian.org/775775
# and https://github.com/docker-library/java/issues/19#issuecomment-70546872
ENV CA_CERTIFICATES_JAVA_VERSION 20170531+nmu1

# OpenJDK:
## deal with slim variants not having man page directories (which causes "update-alternatives" to fail)
## verify that "docker-java-home" returns what we expect
## update-alternatives so that future installs of other OpenJDK versions don't change /usr/bin/java
## ... and verify that it actually worked for one of the alternatives we care about
## see CA_CERTIFICATES_JAVA_VERSION notes above
RUN set -ex; \
	if [ ! -d /usr/share/man/man1 ]; then \
		mkdir -p /usr/share/man/man1; \
	fi; \
	apt-get update; \
	apt-cache madison openjdk-8-jre; \
	apt-cache madison ca-certificates-java; \
	apt-get install -y \
		openjdk-8-jre \
		ca-certificates-java="$CA_CERTIFICATES_JAVA_VERSION"; \
	rm -rf /var/lib/apt/lists/*; \
	[ "$(readlink -f "$JAVA_HOME")" = "$(docker-java-home)" ]; \
	update-alternatives --get-selections | awk -v home="$(readlink -f "$JAVA_HOME")" 'index($3, home) == 1 { $2 = "manual"; print | "update-alternatives --set-selections" }'; \
	update-alternatives --query java | grep -q 'Status: manual'; \
  /var/lib/dpkg/info/ca-certificates-java.postinst configure
