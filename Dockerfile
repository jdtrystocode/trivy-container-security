FROM nginx:1.30.5-alpine3.24

RUN apk upgrade --no-cache

COPY app/index.html /usr/share/nginx/html/index.html

EXPOSE 80
