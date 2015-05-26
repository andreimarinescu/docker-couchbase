FROM ubuntu:14.04
MAINTAINER LifeGadget <contact-us@lifegadget.co>
 
# Basic environment setup
# note: SpiderMonkey build req's: https://developer.mozilla.org/en-US/docs/Mozilla/Developer_guide/Build_Instructions/Linux_Prerequisites
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
	&& apt-get install -y librtmp0 python-httplib2 language-pack-en-base vim wget \
	&& dpkg-reconfigure locales

# Downloading and Installing Couchbase
#http://packages.couchbase.com/releases/3.0.1/couchbase-server-community_3.0.1-ubuntu12.04_amd64.deb
ENV CB_VERSION 3.0.1
ENV CB_FILENAME couchbase-server-community_${CB_VERSION}-ubuntu12.04_amd64.deb
ENV CB_SOURCE http://packages.couchbase.com/releases/$CB_VERSION/$CB_FILENAME
RUN wget -O/tmp/$CB_FILENAME $CB_SOURCE  \ 
	&& dpkg -i /tmp/$CB_FILENAME  \
	&& rm /tmp/$CB_FILENAME

# SpiderMonkey, jsawk, and resty
RUN apt-get install -y libmozjs-24-bin \
	&& ln -s /usr/bin/js24 /usr/local/bin/js \
	&& echo "export JS=/usr/local/bin/js" > /etc/jsawkrc \
	&& wget -O/usr/local/bin/jsawk http://github.com/micha/jsawk/raw/master/jsawk \
	&& wget -O/usr/local/bin/resty http://github.com/micha/resty/raw/master/resty \
	&& chmod +x /usr/local/bin/jsawk /usr/local/bin/resty \
	&& { \
		echo ""; \
		echo "source /usr/local/bin/resty -W 'http://localhost:8091/pools/default'"; \
		echo ""; \
	} >> /etc/bash.bashrc

# Create directory structure for volume sharing
RUN mkdir -p /app \
	&& mkdir -p /app/data \
	&& mkdir -p /app/index \
	&& mkdir -p /app/resources \
	&& mkdir -p /app/conf \
	&& mkdir -p /app/backup \
	&& chown -R couchbase:couchbase /app
VOLUME ["/app/data"]
VOLUME ["/app/backup"]
VOLUME ["/app/volume"]

# Add bootstrapper
ADD resources/docker-couchbase /usr/local/bin/docker-couchbase
RUN export PATH=$PATH:/opt/couchbase/bin \
	&& echo "export PATH=$PATH:/opt/couchbase/bin" >> /etc/bash.bashrc
EXPOSE 8091 8092 11210

# Add a nicer bashrc config
ADD https://raw.githubusercontent.com/lifegadget/bashrc/master/snippets/history.sh /etc/bash.history
ADD https://raw.githubusercontent.com/lifegadget/bashrc/master/snippets/color.sh /etc/bash.color
ADD https://raw.githubusercontent.com/lifegadget/bashrc/master/snippets/shortcuts.sh /etc/bash.shortcuts
RUN { \
		echo ""; \
		echo 'source /etc/bash.history'; \
		echo 'source /etc/bash.color'; \
		echo 'source /etc/bash.shortcuts'; \
	} >> /etc/bash.bashrc

# Lumberjack
RUN apt-get update \
	&& apt-get install -yqq wget curl
ENV LUMBERJACK_VERSION 0.3.1
RUN	wget --no-check-certificate -O/tmp/lumberjack_${LUMBERJACK_VERSION}_amd64.deb https://github.com/lifegadget/lumberjack-builder/raw/master/resources/lumberjack_${LUMBERJACK_VERSION}_amd64.deb \
	&& dpkg -i /tmp/lumberjack_${LUMBERJACK_VERSION}_amd64.deb \
	&& rm /tmp/lumberjack_${LUMBERJACK_VERSION}_amd64.deb 
COPY resources/logstash-forwarder.conf /app/logstash-forwarder.conf
# COPY resources/logstash-init /etc/init.d/lumberjack
COPY resources/logstash-defaults /etc/default/lumberjack

# Add Resources
ENV CLUSTER_RAMSIZE 600
ADD resources/couchbase.txt /app/resources/couchbase.txt
ADD resources/docker.txt /app/resources/docker.txt
ADD resources/default.conf /app/conf/default.conf
ADD resources/dev_models.ddoc /app/conf/dev_models.ddoc
ADD resources/dev_state_document.ddoc /app/conf/dev_state_document.ddoc

ENTRYPOINT ["docker-couchbase"]
CMD	["start"]
CMD	["create"]