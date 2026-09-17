FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/squidfunk/mkdocs-material:9.6

COPY requirements.txt /opt/requirements.txt

# 使用阿里云Alpine镜像（国内速度最快）
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache musl-dev make gcc g++ && \
    rm -rf /var/cache/apk/*

# 使用阿里云PyPI镜像
RUN pip install --no-cache-dir \
    -i https://mirrors.aliyun.com/pypi/simple/ \
    --trusted-host mirrors.aliyun.com \
    -r /opt/requirements.txt

WORKDIR /docs
EXPOSE 8000
ENTRYPOINT ["mkdocs"]
CMD ["serve", "--dev-addr", "0.0.0.0:8000", "--livereload"]


# docker build -t  harbor.devops.io/library/mkdocs-material:v9.6 .
# docker run -p 8000:8000 -v $(pwd):/docs harbor.devops.io/library/mkdocs-material:v9.6