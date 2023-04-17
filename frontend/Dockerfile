# build
FROM gitlab.praktikum-services.ru:5050/v.surin/momostore/node:16 as builder
ARG VERSION=${VERSION}
WORKDIR /frontend/
COPY . .
RUN npm install
#RUN npm run build -- --output-path=/dist
RUN npm run build -- --output-path=/dist

#release
FROM gitlab.praktikum-services.ru:5050/v.surin/momostore/nginx:latest
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /dist/ /usr/share/nginx/html
#COPY --from=builder ./ /usr/share/nginx/html
USER root
RUN chmod -R 775 /usr/share/nginx/html/
EXPOSE 80
#ENTRYPOINT ["nginx"]
