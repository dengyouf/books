# install
### dev

```shell
pip install -r ./requirements.txt -i http://mirrors.aliyun.com/pypi/simple --trusted-host mirrors.aliyun.com
mkdocs serve --dev-addr 127.0.0.1:8000 --watch docs --watch mkdocs.yml  --livereload
```

### 部署发布

```shell
bash release.sh   
```

> 注意观察 ./override 下是否有临时文件， 若有需要手动删除   

### 本地预览
方式一：  
```bash
~/sredocs (main*) » mkdocs serve                                                                                                                   1 ↵ rob@123deMBP
INFO     -  Building documentation...
INFO     -  Building documentation...
INFO     -  Cleaning site directory
INFO     -  The following pages exist in the docs directory, but are not included in the "nav" configuration:
              - chaos/installation/prerequisite.md
              - chaos/requirements/network copy.md
              - raptor/01-tekton.md
INFO     -  Documentation built in 0.57 seconds
INFO     -  [11:38:15] Watching paths for changes: 'docs', 'mkdocs.yml'
INFO     -  [11:38:15] Serving on http://127.0.0.1:8000/
```   
    
方式二:
```bash
~/sredocs (main) » mkdocs build                                                                                                                        rob@123deMBP
INFO     -  Cleaning site directory
INFO     -  Building documentation to directory: /Users/rob/git/raptor/raptor-doc/site
INFO     -  The following pages exist in the docs directory, but are not included in the "nav" configuration:
              - chaos/installation/prerequisite.md
              - chaos/requirements/network copy.md
              - raptor/01-tekton.md
INFO     -  Documentation built in 0.71 seconds

~/sredocs  (main) » cd site
~/sredocs  (main) » python3 -m http.server
Serving HTTP on :: port 8000 (http://[::]:8000/) ...
```   
     
方式三:
```bash
docker run -p 8000:8000 -v ./docs:/docs harbor.devops.io/library/mkdocs-material:v9.6
```
