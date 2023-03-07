# NGINX Param Files

The nginx configuration files were splitten into some snippets here and there to help you override some of the default settings and easily add more settings.

See bellow the list of files and their respective usage

- [orchetration.conf](../base/nginx/orchestration.conf)
  - This file is used to setup the `/orchestration/php-fpm-status` world block, and the `/healthz` ping endpoint.
- [php-location-params.conf](../base/nginx/php-location-params.conf)
  - This file is used to setup all the needed cache and php-fpm params usually used by Laravel.
- [metrics.conf](../base/nginx/metrics.conf)
  - Used to setup the needed stub_status for the prometheus scrapper
- [static-file-params.conf](../base/nginx/static-files-params.conf)
  - Used to setup cache headers for static files

## Adding extra configs

You can always add files to the `/etc/nginx/conf.d` directory, all ending with `.conf` and these files will be loaded by nginx at startup, this might help you to setup extra configs for other locations, or any other config you might be interested on.

## Common Attacks Block

We have a snippet file in the `/etc/nginx/snippets/common-attacks-block.conf` path, you can see the source [here](../base/nginx/common-attacks-block.conf).

In order to enable it you can use this sample Dockerfile

```Dockerfile
FROM 8sistemas/laravel-alpine:8.1-alpine3.16-mysql-nginx
USER root

RUN ln -s /etc/nginx/snippets/common-attacks-block.conf /etc/nginx/conf.d/common-attacks-block.conf

USER www-data
```