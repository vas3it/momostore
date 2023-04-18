# build
FROM gitlab.praktikum-services.ru:5050/v.surin/momostore/node:16 as builder
ARG VERSION=${VERSION}
WORKDIR '/app'
COPY . .
RUN npm install
RUN npm run build -- --output-path=/dist

#release
FROM gitlab.praktikum-services.ru:5050/v.surin/momostore/nginx:latest
RUN rm -rf /usr/share/nginx/html/*
#RUN mkdir /usr/share/nginx/html/momo-store
COPY --from=builder /app/dist /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf
COPY ./nginx/default.conf /etc/nginx/conf.d/
USER root
RUN chmod -R 775 /usr/share/nginx/html
EXPOSE 80
#ENTRYPOINT ["nginx"]
