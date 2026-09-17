VersionFile="./overrides/main.html"
baseDir=$( cd "$( dirname "$0" )" && pwd)

# check distribution
distributionTag=`uname -s`
case $distributionTag in
"Linux")
  distribution="linux"
  dockerBin="podman"
  sedArgs=""
  ;;
"Darwin")
  distribution="darwin"
  dockerBin="docker"
  sedArgs=" "
  ;;
"*")
  distribution="linux"
  dockerBin="podman"
  sedArgs=""
esac


# branch=`git branch --show-current`
# branch=`git branch | sed 's/^\* //g'`
commitHash=`git log --pretty=format:"%h" -n 1`
commitAuthor=`git log --pretty=format:"%ae" -n 1`
commitMessage=`git log --pretty=format:"%s" -n 1`
commitDate=`git log --pretty=format:"%ci" -n 1`

#cp ${VersionFile} ${VersionFile}.bk
#sed -i ${sedArgs} -e "s[GITCOMMIT[${commitHash}[g;s[GITDATE[${commitDate}[g;s[GITAUTH[${commitAuthor}[g;s[GITMSG[${commitMessage}[g" ${VersionFile}

cat > overrides/main.html << EOF
{% extends "base.html" %}

{% block announce %}
  <p><b>发布时间:</b> <i>${commitDate}</i> <b>版本信息:</b> <i>${commitHash}</i>  <b>提交者:</b> <i>${commitAuthor}</i>  <b>摘要:</b> <i>${commitMessage}</i></p>
{% endblock %}
EOF


#${dockerBin} run --rm \
#  -v ${baseDir}:/docs \
#  harbor.devops.io/library/mkdocs-material:v9.6   build
mkdocs build

if [ $? -ne 0 ]; then echo "build failed, now exiting"; exit 1; fi

#mv  ${VersionFile}.bk ${VersionFile}

rsync -av --exclude=site/pdf/document.pdf  site/  root@172.16.162.250:/var/www/html