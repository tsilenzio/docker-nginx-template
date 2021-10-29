FROM nginx:latest

RUN  echo 'deb http://deb.debian.org/debian bullseye-backports main' > /etc/apt/sources.list.d/backports.list \
      && apt-get update \
      && apt-get install -y cron certbot python-certbot-nginx bash wget \
      && apt-get -t bullseye-backports install -y inotify-tools \
      && rm -rf /var/lib/apt/lists/* \
      && rm -rf /etc/nginx/nginx.conf /etc/nginx/conf.d \
      && ln -s /app/config/conf.d /etc/nginx/conf.d \
      && ln -s /app/config/nginx.conf /etc/nginx/nginx.conf \
      && echo "PATH=$PATH" > /etc/cron.d/certbot-renew  \
      && echo "0 */12 * * * certbot renew --nginx >> /var/log/cron.log 2>&1" >> /etc/cron.d/certbot-renew \
      && crontab /etc/cron.d/certbot-renew

ENTRYPOINT [ "/app/entrypoint.sh" ]
