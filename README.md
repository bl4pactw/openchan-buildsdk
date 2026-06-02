# openchan

本專案適合用來建立 QuecOpen SDK 各硬體平台以 Docker 為基礎的編譯環境，包含 ASR1806、SDX35、SDX6x、SDX7x、SDX8x、T830、V620 等平台，以及給 Jenkins/CI 使用的固定使用者版本。

## Docker Hub 預建鏡像

本專案中的 Dockerfile 與 Docker Hub 上的 [`bradlu4`](https://hub.docker.com/u/bradlu4) image 相互對應。一般客戶或使用者可優先直接 `docker pull` 預建鏡像，避免在本機重新安裝大量套件與等待 Docker build；只有在需要調整套件、更新 Dockerfile 或建立內部版本時，再使用本 repo 的 Dockerfile 重新 build。

| 平台 / 用途 | Docker Hub image | 目前主要 tag | 對應 Dockerfile |
| --- | --- | --- | --- |
| ASR1806 SDK | `bradlu4/ub1604-quecopen-asr1806sdk-img` | `250909` | `dockerfile-quecopen-asr1806-sdk-ub1604` |
| SDX35 SDK | `bradlu4/ub1804-quecopen-x35sdk-img` | `250909` | `dockerfile-quecopen-sdx35-sdk-ub1804` |
| SDX6x SDK | `bradlu4/ub1804-quecopen-x6xsdk-img` | `250917` | `dockerfile-quecopen-sdx6x-sdk-ub1804` |
| SDX7x SDK | `bradlu4/ub1804-quecopen-x7xsdk-img` | `250909` | `dockerfile-quecopen-sdx7x-sdk-ub1804` |
| SDX8x SDK | `bradlu4/ub2204-quecopen-sdx8x-img` | `260528` | `dockerfile-quecopen-sdx8x-sdk-ub2204` |
| T830 SDK, Ubuntu 18.04 | `bradlu4/ub1804-quecopen-t830sdk-img` | `250909` | `dockerfile-quecopen-t830-sdk-ub1804` |
| T830 SDK, Ubuntu 22.04 | `bradlu4/ub2204-quecopen-t830sdk-img` | `250909` | `dockerfile-quecopen-t830-sdk-ub2204` |
| T830 CI, Ubuntu 18.04 | `bradlu4/ub1804-ci-quecopen-t830-img` | `latest` | `dockerfile-quecopen-t830-sdk-ub1804-ci` |
| V620 SDK | `bradlu4/ub2004-quecopen-v620-img` | `latest` | `dockerfile-quecopen-v620-sdk-ub2004` |

> Docker Hub 的 tag 可能會隨 image 發布而更新，實際可用 tag 請以各 image 的 Tags 頁面為準。

## 快速開始：使用預建 image

先從 Docker Hub 拉取對應平台的 image，例如 SDX8x：

```bash
docker pull bradlu4/ub2204-quecopen-sdx8x-img:260528
```

啟動互動式容器並掛載目前專案目錄：

```bash
docker run -it --rm \
  -e LOCAL_UID=$(id -u) \
  -e LOCAL_GID=$(id -g) \
  -e LOCAL_USER=$(id -un) \
  -v "$(pwd):/home/$(id -un)/repo" \
  bradlu4/ub2204-quecopen-sdx8x-img:260528 \
  /bin/bash
```

進入容器後，可將 QuecOpen SDK 放在掛載目錄中，再依 SDK 原本的 build command 進行編譯。

## 從 Dockerfile 自行 build

若需要自行修改或重新生成 image，可選擇對應平台 Dockerfile，例如 T830 Ubuntu 22.04：

```bash
docker build -t openchan-t830-ub2204 -f dockerfile-quecopen-t830-sdk-ub2204 .
```

再用本機 image 啟動容器：

```bash
docker run -it --rm \
  -e LOCAL_UID=$(id -u) \
  -e LOCAL_GID=$(id -g) \
  -e LOCAL_USER=$(id -un) \
  -v "$(pwd):/home/$(id -un)/repo" \
  openchan-t830-ub2204 \
  /bin/bash
```

## 專案內容

| 檔案 | 用途 |
| --- | --- |
| `dockerfile-quecopen-asr1806-sdk-ub1604` | ASR1806 SDK 編譯環境，Ubuntu 16.04 |
| `dockerfile-quecopen-sdx35-sdk-ub1804` | SDX35 SDK 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-sdx6x-sdk-ub1804` | SDX6x SDK 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-sdx7x-sdk-ub1804` | SDX7x SDK 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-sdx7x-sdk-ub1804-ci` | SDX7x SDK CI 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-sdx8x-sdk-ub2204` | SDX8x SDK 編譯環境，Ubuntu 22.04 |
| `dockerfile-quecopen-sdx8x-sdk-ub2204-ci` | SDX8x SDK CI 編譯環境，Ubuntu 22.04 |
| `dockerfile-quecopen-t830-sdk-ub1804` | T830 SDK 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-t830-sdk-ub1804-ci` | T830 SDK CI 編譯環境，Ubuntu 18.04 |
| `dockerfile-quecopen-t830-sdk-ub2204` | T830 SDK 編譯環境，Ubuntu 22.04 |
| `dockerfile-quecopen-t830-sdk-ub2204-ci` | T830 SDK CI 編譯環境，Ubuntu 22.04 |
| `dockerfile-quecopen-v620-sdk-ub2004` | V620 SDK 編譯環境，Ubuntu 20.04 |
| `dockerfile-vscode-common-ub2204` | VS Code / common 開發用基礎環境，Ubuntu 22.04 |
| `entrypoint.sh` | 依照主機 UID/GID 建立容器內使用者，降低 volume 權限問題 |
| `script-dev/` | 建置、啟動與除錯 Docker image/container 的輔助腳本 |

## 特色

- 針對不同 QuecOpen SDK 平台準備對應的 Ubuntu 版本與編譯相依套件。
- Docker Hub 已提供常用平台的預建 image，可直接拉取使用，降低客戶端重建環境的時間成本。
- 開發用 Dockerfile 會透過 `entrypoint.sh` 建立與主機 UID/GID 對應的使用者，方便掛載 SDK 或 repo 目錄後直接編譯。
- CI 版 Dockerfile 使用固定的 `builder` 帳號與 `/workspace` 工作目錄，適合 Jenkins 或自動化建置流程。
- 預設 locale 為 `en_US.UTF-8`，時區設定為 `Asia/Taipei`。
- T830 環境另外準備 Ninja 與 GN 等建置工具。

## 使用 script-dev 腳本

`script-dev/new-sdk-build.sh` 可用來建立 Docker image：

```bash
cd script-dev
./new-sdk-build.sh openchan-sdx7x ../dockerfile-quecopen-sdx7x-sdk-ub1804
```

`script-dev/run-sdk-build.sh` 可用來建立或重新進入容器：

```bash
cd script-dev
./run-sdk-build.sh sdx7x-openchan openchan-sdx7x
```

若容器已存在，可只帶 container name：

```bash
./run-sdk-build.sh sdx7x-openchan
```

`script-dev/docker_uid_gid_debug.sh` 用於檢查掛載目錄在容器內外的 UID/GID 與檔案建立權限。

`script-dev/update-all-images.ps1` 是 PowerShell 批次 build/tag/push image 的腳本，可依需要調整 Docker Hub 使用者、image 名稱與 Dockerfile 清單。

## 開發用與 CI 用 Dockerfile 差異

一般開發用 Dockerfile 會複製並使用 `entrypoint.sh`：

- 透過 `LOCAL_UID`、`LOCAL_GID`、`LOCAL_USER` 建立容器內使用者。
- 讓容器內使用者取得免密碼 sudo 權限。
- 修正 `/home/<user>/sdk` 掛載目錄權限。
- 最後使用 `gosu` 切換到該使用者執行命令。

CI 用 Dockerfile 則不啟用開發用 entrypoint，改用固定帳號：

- 建立 `builder` 使用者與群組，UID/GID 皆為 `1000`。
- 工作目錄設定為 `/workspace`。
- 預設以 `builder` 使用者啟動，方便 Jenkins 等 CI 環境維持一致權限。

## 建議命名

建立 image 時建議在名稱中保留 Ubuntu 版本、平台與用途，例如：

```text
ub1804-quecopen-sdx7x-sdk
ub2204-quecopen-t830-sdk
ub2204-quecopen-sdx8x-sdk-ci
```

這樣可以在本機或 CI registry 中快速辨識 image 對應的平台與基底系統版本。

## 注意事項

- Docker Hub 預建 image 是為了減少客戶端重新生成 image 的動作；若需要完全可追溯的內部版本，建議保留對應 Dockerfile 與 image tag。
- Dockerfile 會安裝大量 SDK build dependencies，第一次 build 可能需要較長時間。
- 部分 Dockerfile 會從外部下載工具，例如 Ninja 或 GN，build 時需可連線到對應來源。
- `script-dev/run-sdk-build.sh` 需要目前使用者具備 Docker 權限，通常需加入 `docker` group。
- 實際 SDK 編譯指令仍以各 QuecOpen SDK release package 內的文件為準。
