### Docker 使用流程簡介: 
1) 生成 docker image
2) 使用 docker image 生成 docker container
3) 啟動/停止 docker container
4) (Option) 在 docker container 中操作 (通常我們會在 docker container 手動進行 QuecOpen build )

**一旦 docker container 生成，我們可以不用再進行步驟 2)，只要重覆進行 3) 跟 4)**

### 1) 生成 image
```sh
sudo docker build -t "ub1804-quecopen-x6xsdk-img" --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) --build-arg USER=$(id -gn) -f dockerfile-quecopen-sdx6x-sdk .
```
- 設定輸出 image name/tag: ub1804-quecopen-x6xsdk-img
- 輸入 dockerfile 檔名 : dockerfile-quecopen-sdx6x-sdk
- 輸入 dockerfile path: 目錄包含可使用的 dockerfile, 在當前目錄就使用 **.** 表示

### 2) create container
```sh
docker run -it -v /home/$(id -gn)/repo:/home/$(id -un)/repo -d --name ub1804-quecopen-sdx6-sdk ub1804-quecopen-x6xsdk-img /bin/bash
```
連結 本地端目錄與 container 內目錄，底下為建議路徑，依自身環境修改
- mount path on host: /home/$(id -gn)/repo that we have to prepare the user's repo folder.
- mount path on container: /home/$(id -gn)/repo 

- 需參考 image : ub1804-quecopen-x6xsdk-img，使用 1) 生成的 image
- 設定輸出 container 名字: ub1804-quecopen-sdx6-sdk
- 第一次生成 container 會自行啟動，可跳過 3) 直接到 4)

### 3) start/stop container
```sh
# 啟動 container:
docker start ub1804-quecopen-sdx6-sdk

# 停止 container:
docker stop ub1804-quecopen-sdx6-sdk
```
- 設定啟動/停止 container 名字:  ub1804-quecopen-sdx6-sdk
- 

### 4) 執行 container 內部 shell 進行操作
```sh
docker exec -it --user $(id -un) ub1804-quecopen-sdx6-sdk /bin/bash
```
- 指定 container 名字: ub1804-quecopen-sdx6-sdk
