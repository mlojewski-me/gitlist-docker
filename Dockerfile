FROM alpine:3.20

RUN apk update && apk --no-cache add \
	git \
	nginx \
	php83 \
	php83-ctype \
	php83-dom \
	php83-fpm \
	php83-json \
	php83-mbstring \
	php83-session \
	php83-simplexml \
	php83-tokenizer \
	supervisor


### repository mount point and dummy repository ###
ARG REPOSITORY_ROOT=/repos
ARG REPOSITORY_DUMMY=$REPOSITORY_ROOT/If_you_see_this_then_the_host_volume_was_not_mounted
RUN mkdir -p "$REPOSITORY_DUMMY" \
	&& git --bare init "$REPOSITORY_DUMMY"


### gitlist ####
ARG GITLIST_DOWNLOAD_FILENAME='p3x-gitlist-v2024.4.105.zip'
ARG GITLIST_DOWNLOAD_URL="https://github.com/patrikx3/gitlist/releases/download/v2024.4.105/$GITLIST_DOWNLOAD_FILENAME"
ARG GITLIST_DOWNLOAD_SHA256=2b226c8f7366af903c3ae696d7fff27927e00b9c050df7663064e3d3715f8b8e
RUN NEED='wget unzip sed'; \
	DEL='unzip' \
	&& for x in $NEED; do \
		if [ $(apk list "$x" | grep -F [installed] | wc -l) -eq 0 ]; then \
			DEL="$DEL $x" \
			&& echo "Add temporary package $x" \
			&& apk --no-cache add $x; \
		fi; \
	done \
	&& cd /var/www \
	&& wget -q "$GITLIST_DOWNLOAD_URL" -O "$GITLIST_DOWNLOAD_FILENAME" \
	&& sha256sum "$GITLIST_DOWNLOAD_FILENAME" \
	&& echo "$GITLIST_DOWNLOAD_SHA256  $GITLIST_DOWNLOAD_FILENAME" | sha256sum -c - \
	&& unzip -u "$GITLIST_DOWNLOAD_FILENAME" -d gitlist \
	&& rm "$GITLIST_DOWNLOAD_FILENAME" \
	&& if [ -n "$DEL" ]; then echo "Delete temporary package(s) $DEL" && apk del $DEL; fi \
	&& mkdir -p gitlist/cache \
	&& chmod a+trwx gitlist/cache \
	&& rm gitlist/public/web.config \
	&& rm gitlist/public/.htaccess

COPY copy /
EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["gitlist"]
