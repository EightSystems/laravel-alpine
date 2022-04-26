# Prometheus Scrapper

We added prometheus exporters to all the images, the `*-nginx` ones have both php-fpm-exporter and nginx-exporter (joined together with `exporter-combiner` so you get all the metrics in a single endpoint), the non `*-nginx` ones have only the php-fpm-exporter, as this is the only metric we have from this container image.

In order to save memory, the exporters only run when the environment variable `ENABLE_PROMETHEUS_EXPORTER_RUNNER` is set to `1`, see the [docker-compose.yaml](../8.1/docker-compose.yaml) or the [kube-pod.yaml](../8.1/kube-pod.yaml) for samples on how to enable them.
