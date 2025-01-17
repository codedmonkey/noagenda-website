FROM node:20.10-alpine AS assets

WORKDIR /srv/app

ENV FPM_HOST=app
ENV FPM_PORT=9000

# Install dependencies
COPY package.json package-lock.json ./
RUN set -eux; \
    npm install; \
	npm cache clean --force

# Compile assets
COPY .babelrc .eslintrc.json jest.config.js webpack.config.js ./
COPY assets assets/
RUN set -eux; \
    npm run production

# Set up entrypoint
COPY docker/assets-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["npm", "run", "watch"]

FROM php:8.2-fpm-bookworm AS app

ARG UID=3302
ARG GID=3302

ENV FPM_HOST=app
ENV FPM_PORT=9000

ARG GITHUB_TOKEN

USER root
RUN rm -rf /srv/app

RUN mkdir -p /srv/app; chown $UID:$GID /srv/app
WORKDIR /srv/app

# Configure app user
RUN groupdel dialout; \
    groupadd --gid $GID ben; \
    useradd --uid $UID --gid $GID --create-home ben; \
    sed -i "s/user = www-data/user = ben/g" /usr/local/etc/php-fpm.d/www.conf; \
    sed -i "s/group = www-data/group = ben/g" /usr/local/etc/php-fpm.d/www.conf

# Install persistent & runtime dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y git netcat-traditional procps; \
    rm -rf /var/lib/apt/lists/*

# Install media utilities
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y ffmpeg; \
    rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y libmagickwand-dev; \
    pecl install imagick; \
	docker-php-ext-enable imagick; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y libicu-dev; \
    docker-php-ext-install intl; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    docker-php-ext-install pdo_mysql

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y libzip-dev unzip; \
	docker-php-ext-install zip; \
    rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN if [ ! -z "$GITHUB_TOKEN" ]; then composer config --global github-oauth.github.com $GITHUB_TOKEN; fi

# Set up entrypoints
COPY docker/app-entrypoint.bash /usr/local/bin/app-entrypoint
RUN chmod +x /usr/local/bin/app-entrypoint

COPY docker/php-entrypoint.bash /usr/local/bin/app-php-entrypoint
RUN chmod +x /usr/local/bin/app-php-entrypoint

ENTRYPOINT ["app-entrypoint"]
CMD ["php-fpm"]

USER ben

# Copy application directory contents
COPY --chown=ben:ben license.markdown readme.markdown ./
COPY --chown=ben:ben composer.json composer.lock symfony.lock ./
COPY --chown=ben:ben .env ./
COPY --chown=ben:ben .env.test phpunit.xml.dist ./
COPY --chown=ben:ben bin bin/
COPY --chown=ben:ben config config/
COPY --chown=ben:ben migrations migrations/
COPY --chown=ben:ben public public/
COPY --chown=ben:ben src src/
COPY --chown=ben:ben templates templates/
COPY --chown=ben:ben tests tests/
COPY --chown=ben:ben translations translations/

COPY --from=assets --chown=ben:ben /srv/app/public public/

RUN mkdir -p \
        docker/storage/chapters \
        docker/storage/covers \
        docker/storage/episodes \
        docker/storage/shownotes \
        docker/storage/transcripts \
        public/media \
        var/cache \
        var/log

# Run Composer commands
RUN set -eux; \
    chmod +x bin/console; \
    composer install --no-autoloader --no-dev --no-progress --no-scripts; \
    composer clear-cache; \
    composer dump-autoload --classmap-authoritative; \
    APP_ENV=prod bin/console cache:warmup; \
    APP_ENV=prod composer run-script post-install-cmd

FROM nginx:alpine AS web

ENV FPM_HOST=app
ENV FPM_PORT=9000

WORKDIR /srv/app

# Copy Nginx configuration
RUN rm /etc/nginx/conf.d/default.conf
COPY docker/nginx/app.conf.template /etc/nginx/templates/

# Copy application directory contents
COPY --from=app /srv/app/public public/
