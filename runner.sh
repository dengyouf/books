desc="docs-ci"
tk=$1


if [ "x${tk}" == "x" ]
then
echo "miss tk , usage: bash runner.sh token "
exit 1
fi

docker run -d --name ${desc} --restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /data/runner:/home/gitlab-runner \
  gitlab-runner:v15.10.1 \
--non-interactive \
--url "http://gitlab.devios.io/" \
--run-untagged true \
--registration-token hkpRJ2NbgosTF6zADxim \
--description ${desc} \
--locked false \
--executor docker \
--docker-image harbor.devops.io/devops/mkdocs-material:v20250527 \
--tag-list "docker,docs"