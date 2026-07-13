# openchan

本專案適合用來建立 QuecOpen SDK 各硬體平台以 Docker 為基礎的編譯環境，包含 ASR1806、SDX35、SDX6x、SDX7x、SDX8x、T830、V620 等平台，以及給 Jenkins/CI 使用的固定使用者版本。

## 三種建置方式

本專案提供三種方式取得或建置 QuecOpen SDK 編譯環境的 Docker container，可依需求擇一使用：

1. **使用 Docker Hub 預建 image**（最快）：直接 `docker pull` 對應平台的預建 image，不需在本機重新 build。適合一般客戶或使用者。詳見〈[Docker Hub 預建鏡像](#docker-hub-預建鏡像)〉與〈[快速開始：使用預建 image](#快速開始使用預建-image)〉。
2. **從個別平台 Dockerfile 自行 build**：使用 `dockerfiles/` 下各平台獨立的 Dockerfile 自行建置，適合需要調整套件或建立內部版本時。詳見〈[從 Dockerfile 自行 build](#從-dockerfile-自行-build)〉。
3. **使用統一 Dockerfile + `build-image.sh` 建置**：透過 `dockerfiles/Dockerfile.unified` 搭配 `build-image.sh`，以平台代號一鍵切換平台與 dev/CI 變體，只需維護一份套件清單。詳見〈[使用統一 Dockerfile 建置](#使用統一-dockerfilebuild-imagesh)〉。

## Docker Hub 預建鏡像

本專案中的 Dockerfile 與 Docker Hub 上的 [`bradlu4`](https://hub.docker.com/u/bradlu4) image 相互對應。一般客戶或使用者可優先直接 `docker pull` 預建鏡像，避免在本機重新安裝大量套件與等待 Docker build；只有在需要調整套件、更新 Dockerfile 或建立內部版本時，再使用本 repo 的 Dockerfile 重新 build。

| 平台 / 用途 | Docker Hub image | 目前主要 tag | 對應 Dockerfile |
| --- | --- | --- | --- |
| ASR1806 SDK | `bradlu4/ub1604-quecopen-asr1806sdk-img` | `250909` | `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` |
| SDX35 SDK | `bradlu4/ub1804-quecopen-x35sdk-img` | `250909` | `dockerfiles/dockerfile-quecopen-sdx35-sdk-ub1804` |
| SDX6x SDK | `bradlu4/ub1804-quecopen-x6xsdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-sdx6x-sdk-ub1804` |
| SDX7x SDK | `bradlu4/ub1804-quecopen-x7xsdk-img` | `250909` | `dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804` |
| SDX8x SDK | `bradlu4/ub2204-quecopen-sdx8x-img` | `260528` | `dockerfiles/dockerfile-quecopen-sdx8x-sdk-ub2204` |
| T830 SDK, Ubuntu 18.04 | `bradlu4/ub1804-quecopen-t830sdk-img` | `250909` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804` |
| T830 SDK, Ubuntu 22.04 | `bradlu4/ub2204-quecopen-t830sdk-img` | `250909` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub2204` |
| T830 CI, Ubuntu 18.04 | `bradlu4/ub1804-ci-quecopen-t830-img` | `latest` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804-ci` |
| V620 SDK | `bradlu4/ub2004-quecopen-v620-img` | `latest` | `dockerfiles/dockerfile-quecopen-v620-sdk-ub2004` |

> Docker Hub 的 tag 可能會隨 image 發布而更新，實際可用 tag 請以各 image 的 Tags 頁面為準。

## 快速開始：使用預建 image

先從 Docker Hub 拉取對應平台的 image，例如 SDX8x：

```bash
docker pull bradlu4/ub2204-quecopen-sdx8x-img:260528
```

啟動互動式容器。這裡只把本地端的 `$HOME/sdk`（由使用者自行準備、用來放置第三方 SDK 源碼包的目錄）掛載到容器內同名使用者的 `~/sdk`；家目錄下的其他檔案（如 `.bashrc`、`.ssh`）本地與容器互不干擾。請先在本地端建立此目錄：

```bash
mkdir -p "$HOME/sdk"   # 把要編譯的 SDK 源碼包放進這裡
```


```bash
docker run -it --rm \
  -e LOCAL_UID=$(id -u) \
  -e LOCAL_GID=$(id -g) \
  -e LOCAL_USER=$(id -un) \
  -v "$HOME/sdk:/home/$(id -un)/sdk" \
  bradlu4/ub2204-quecopen-sdx8x-img:260528 \
  /bin/bash
```

進入容器後，SDK 源碼包會位於 `~/sdk`（即本地端的 `$HOME/sdk`），可依 SDK 原本的 build command 進行編譯。

## 從 Dockerfile 自行 build

若需要自行修改或重新生成 image，可選擇對應平台 Dockerfile，例如 T830 Ubuntu 22.04：

```bash
docker build -t openchan-t830-ub2204 -f dockerfiles/dockerfile-quecopen-t830-sdk-ub2204 dockerfiles
```

再用本機 image 啟動容器：

```bash
docker run -it --rm \
  -e LOCAL_UID=$(id -u) \
  -e LOCAL_GID=$(id -g) \
  -e LOCAL_USER=$(id -un) \
  -v "$HOME/sdk:/home/$(id -un)/sdk" \
  openchan-t830-ub2204 \
  /bin/bash
```

## 使用統一 Dockerfile 建置（`build-image.sh`）

`dockerfiles/Dockerfile.unified` 將 `dockerfiles/` 下各平台獨立的 Dockerfile 整合成一份，透過 `PLATFORM`／`OS_VERSION`／`VARIANT` build args 切換平台與 dev/CI 變體，方便日後只需維護一份套件清單。原本 13 份平台別 Dockerfile 仍保留、可繼續使用，兩種方式並存。

在 repo 根目錄執行 `build-image.sh`，依平台代號產生對應 image：

```bash
# 產生 SDX8x dev image
./build-image.sh -p sdx8x

# 產生 T830 Ubuntu 18.04 CI image
./build-image.sh -p t830 -o ub1804 -v ci

# 自訂 tag
./build-image.sh -p sdx7x -v ci -t my-sdx7x-ci-img

# 列出支援的平台/os/variant 組合
./build-image.sh -l
```

支援的平台代號：`asr1806`、`sdx35`、`sdx6x`、`sdx7x`、`sdx8x`、`t830`、`v620`、`vscode`。只有 `t830` 需要用 `-o` 指定 Ubuntu 版本（`ub1804` 或 `ub2204`）；只有 `sdx7x`／`sdx8x`／`t830` 支援 `-v ci`。預設 tag 命名規則為 `<os_version>-quecopen-<platform>-sdk[-ci]`，如需對齊 Docker Hub 既有名稱可用 `-t` 覆蓋。

Build 完成後的啟動方式與上方「快速開始」相同，將 image 名稱換成建置出來的 tag 即可。

## 專案內容

| 檔案 | 用途 |
| --- | --- |
| `dockerfiles/Dockerfile.unified` | 整合所有平台的統一 Dockerfile，搭配 `build-image.sh` 與 `PLATFORM`/`OS_VERSION`/`VARIANT` build args 使用 |
| `build-image.sh` | 依平台代號呼叫 `dockerfiles/Dockerfile.unified` 產生 image 的建置腳本 |
| `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` | ASR1806 SDK 編譯環境，Ubuntu 16.04 |
| `dockerfiles/dockerfile-quecopen-sdx35-sdk-ub1804` | SDX35 SDK 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-sdx6x-sdk-ub1804` | SDX6x SDK 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804` | SDX7x SDK 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804-ci` | SDX7x SDK CI 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-sdx8x-sdk-ub2204` | SDX8x SDK 編譯環境，Ubuntu 22.04 |
| `dockerfiles/dockerfile-quecopen-sdx8x-sdk-ub2204-ci` | SDX8x SDK CI 編譯環境，Ubuntu 22.04 |
| `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804` | T830 SDK 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804-ci` | T830 SDK CI 編譯環境，Ubuntu 18.04 |
| `dockerfiles/dockerfile-quecopen-t830-sdk-ub2204` | T830 SDK 編譯環境，Ubuntu 22.04 |
| `dockerfiles/dockerfile-quecopen-t830-sdk-ub2204-ci` | T830 SDK CI 編譯環境，Ubuntu 22.04 |
| `dockerfiles/dockerfile-quecopen-v620-sdk-ub2004` | V620 SDK 編譯環境，Ubuntu 20.04 |
| `dockerfiles/dockerfile-vscode-common-ub2204` | VS Code / common 開發用基礎環境，Ubuntu 22.04 |
| `dockerfiles/entrypoint.sh` | 依照主機 UID/GID 建立容器內使用者，降低 volume 權限問題 |
| `script-dev/` | 建置、啟動與除錯 Docker image/container 的輔助腳本（開發中） |

## 特色

- 針對不同 QuecOpen SDK 平台準備對應的 Ubuntu 版本與編譯相依套件。
- Docker Hub 已提供常用平台的預建 image，可直接拉取使用，降低客戶端重建環境的時間成本。
- 開發用 Dockerfile 會透過 `entrypoint.sh` 建立與主機 UID/GID 對應的使用者，方便掛載 SDK 或 repo 目錄後直接編譯。
- CI 版 Dockerfile 使用固定的 `builder` 帳號與 `/workspace` 工作目錄，適合 Jenkins 或自動化建置流程。
- 預設 locale 為 `en_US.UTF-8`，時區設定為 `Asia/Taipei`。
- T830 環境另外準備 Ninja 與 GN 等建置工具。

## 使用 script-dev 腳本（開發中）

> 此目錄仍在開發中，腳本介面、參數與預設 image 名稱可能會調整。穩定使用情境建議優先參考上方 Docker Hub 預建 image 與 Dockerfile build 流程。

`script-dev/new-sdk-build.sh` 可用來建立 Docker image：

```bash
cd script-dev
./new-sdk-build.sh openchan-sdx7x ../dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804
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
- ASR1806（Ubuntu 16.04）因為內建的是 Python 2.7／pip 8.1.1，安裝 `pyhocon` 時**必須鎖定版本** `pip install "pyparsing==2.4.7" "pyhocon==0.3.60"`；否則 pip 會嘗試拉取只支援 Python 3 的新版 `pyparsing` 導致 build 失敗。此為 `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` 與 `Dockerfile.unified` 的 `asr1806` 區塊採用的版本組合，也與 Docker Hub 上既有可用 image（pyparsing 2.4.7 + pyhocon 0.3.60）一致。
- `script-dev/` 目前標示為開發中；`script-dev/run-sdk-build.sh` 需要目前使用者具備 Docker 權限，通常需加入 `docker` group。
- 實際 SDK 編譯指令仍以各 QuecOpen SDK release package 內的文件為準。
