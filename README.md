# openchan

本專案適合用來建立 QuecOpen SDK 各硬體平台以 Docker 為基礎的編譯環境，包含 ASR1806、ASR1903、SDX35、SDX6x、SDX7x、SDX8x、T830、V620 等平台，以及給 Jenkins/CI 使用的固定使用者版本。

## 四種使用方式

本專案提供四種方式取得或建置 QuecOpen SDK 編譯環境的 Docker container，可依需求擇一使用：

0. **使用 `run-image.sh` 一步進入編譯環境**（最推薦，尤其是不熟 Docker 的使用者）：選平台後自動取得 image、掛好 SDK 目錄、直接把你放進容器內的 bash。不需要記任何 docker 指令。詳見〈[一步進入編譯環境](#一步進入編譯環境run-imagesh)〉。
1. **使用 Docker Hub 預建 image**：自己下 `docker pull` 與 `docker run`，適合想完全掌握參數的人。詳見〈[Docker Hub 預建鏡像](#docker-hub-預建鏡像)〉與〈[手動使用預建 image](#手動使用預建-image)〉。
2. **從個別平台 Dockerfile 自行 build**：使用 `dockerfiles/` 下各平台獨立的 Dockerfile 自行建置，適合需要調整套件或建立內部版本時。詳見〈[從 Dockerfile 自行 build](#從-dockerfile-自行-build)〉。
3. **使用統一 Dockerfile + `build-image.sh` 建置**：透過 `dockerfiles/Dockerfile.unified` 搭配 `build-image.sh`，以平台代號一鍵切換平台與 dev/CI 變體，只需維護一份套件清單。詳見〈[使用統一 Dockerfile 建置](#使用統一-dockerfilebuild-imagesh)〉。

第 0 種是第 1 種的自動化封裝：它一樣走「優先拉取預建 image」的路線，只是把選平台、命名、掛載、UID/GID 對應這些步驟包起來。需要自訂參數時再往下看第 1～3 種。

## Docker Hub 預建鏡像

本專案中的 Dockerfile 與 Docker Hub 上的 [`bradlu4`](https://hub.docker.com/u/bradlu4) image 相互對應。一般客戶或使用者可優先直接 `docker pull` 預建鏡像，避免在本機重新安裝大量套件與等待 Docker build；只有在需要調整套件、更新 Dockerfile 或建立內部版本時，再使用本 repo 的 Dockerfile 重新 build。

開發（dev）用 image：

| 平台 / 用途 | Docker Hub image | 目前主要 tag | 對應 Dockerfile |
| --- | --- | --- | --- |
| ASR1806 SDK | `bradlu4/ub1604-quecopen-asr1806sdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` |
| SDX35 SDK | `bradlu4/ub1804-quecopen-x35sdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-sdx35-sdk-ub1804` |
| SDX6x SDK | `bradlu4/ub1804-quecopen-x6xsdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-sdx6x-sdk-ub1804` |
| SDX7x SDK | `bradlu4/ub1804-quecopen-x7xsdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804` |
| SDX8x SDK | `bradlu4/ub2204-quecopen-sdx8x-img` | `260528` | `dockerfiles/dockerfile-quecopen-sdx8x-sdk-ub2204` |
| T830 SDK, Ubuntu 18.04 | `bradlu4/ub1804-quecopen-t830sdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804` |
| T830 SDK, Ubuntu 22.04 | `bradlu4/ub2204-quecopen-t830sdk-img` | `250917` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub2204` |
| V620 SDK | `bradlu4/ub2004-quecopen-v620-img` | `latest` | `dockerfiles/dockerfile-quecopen-v620-sdk-ub2004` |

CI 用 image（固定 `builder` 帳號 + `/workspace`，供客戶建置自己的 CI/CD 流程時參考）：

| 平台 / 用途 | Docker Hub image | 目前主要 tag | 對應 Dockerfile |
| --- | --- | --- | --- |
| SDX7x CI, Ubuntu 18.04 | `bradlu4/ub1804-ci-quecopen-sdx7x-img` | `latest` | `dockerfiles/dockerfile-quecopen-sdx7x-sdk-ub1804-ci` |
| SDX8x CI, Ubuntu 22.04 | `bradlu4/ub2204-ci-quecopen-sdx8x-img` | `latest` | `dockerfiles/dockerfile-quecopen-sdx8x-sdk-ub2204-ci` |
| T830 CI, Ubuntu 18.04 | `bradlu4/ub1804-ci-quecopen-t830-img` | `latest` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub1804-ci` |
| T830 CI, Ubuntu 22.04 | `bradlu4/ub2204-ci-quecopen-t830-img` | `latest` | `dockerfiles/dockerfile-quecopen-t830-sdk-ub2204-ci` |

> Docker Hub 的 tag 可能會隨 image 發布而更新，實際可用 tag 請以各 image 的 Tags 頁面為準。
>
> **ASR1903 目前還沒有預建 image**，需要先用 `./build-image.sh -p asr1903` 自行建置，再用
> `./run-image.sh -p asr1903 -i <建置出來的 image>` 啟動。注意不要拿 ASR1806 的 image 頂替──
> 那是 Ubuntu 16.04 加 python2.7/pyhocon 的組合，與 ASR1903 需要的 Ubuntu 20.04 環境不符。
>
> `run-image.sh` 實際使用的 image 與 tag 定義在 `platforms.sh` 的 `PLATFORM_HUB_IMAGE`；
> 發布新 image 後請一併更新該表，本節表格僅供人閱讀。

## 一步進入編譯環境（`run-image.sh`）

`run-image.sh` 把「取得 image → 掛載 SDK → 進入容器 bash」串成一步。它只走 dev 路徑，
預設優先使用 Docker Hub 預建 image，不需要事先 build。

```bash
# 互動式選單：列出平台讓你選編號
./run-image.sh

# 直接指定平台
./run-image.sh -p sdx8x

# T830 需要選 Ubuntu 版本（不指定則預設 ub2204）
./run-image.sh -p t830 -o ub1804

# 更新到最新的 image（平時不會重新下載）
./run-image.sh -p sdx8x -u

# 使用自行 build 出來的 image，略過 Docker Hub 對照表
./run-image.sh -p asr1903 -i ub2004-quecopen-asr1903-sdk
```

### SDK 放哪裡

SDK 源碼包一律放在本 repo 目錄下的 `sdk/`（腳本第一次執行時會自動建立），容器內固定掛在
**`/sdk`**，進入容器後的工作目錄也直接落在那裡：

```text
openchan-buildsdk/
├── run-image.sh
├── build-image.sh
├── platforms.sh
└── sdk/              ← 把 SDK release package 解開放這裡（已列入 .gitignore）
    ├── sdx8x-sdk/
    └── t830-sdk/
```

整個 `sdk/` 會一起掛進容器，所以可以同時放多個平台的 SDK，進去之後自己 `cd` 到要編譯的那一份。
實際編譯指令依各 SDK release package 內的文件為準。

> **為什麼是 `/sdk` 而不是 `~/sdk`？**
>
> image 內建的 `dockerfiles/entrypoint.sh` 有這一段：
>
> ```bash
> if [ -d "/home/${USER_NAME}/sdk" ]; then
>     chown -R ${USER_ID}:${GROUP_ID} /home/${USER_NAME}/sdk
> fi
> ```
>
> 那個 `chown -R` 是無條件執行的——GNU chown 即使目標擁有者與現況完全相同，仍會對每個檔案
> 發出一次 syscall，並且清除一般執行檔上的 setuid/setgid 位元。對動輒數十萬到數百萬個
> inode 的 SDK 樹，這代表每次啟動都要付一次全樹掃描的代價；若 SDK 內含廠商預先以 root
> 解開、帶有真實 setuid 的 target rootfs，還會靜默破壞 `busybox`／`su`／`ping` 的權限。
>
> 由於 `entrypoint.sh` 必須與 Docker Hub 上已發布 image 內的版本保持完全一致（不修改、
> 也不在執行時覆蓋），`run-image.sh` 改為掛在 `/sdk`。那個 `if [ -d ... ]` 的條件因此
> 永遠不成立，整段直接跳過。權限交由使用者自行掌控。
>
> 手動 `docker run` 時仍可沿用既有的 `~/sdk` 約定（見〈[手動使用預建 image](#手動使用預建-image)〉），
> 只是會保留上述的自動 chown 行為。

### 這支腳本的固定行為

- **容器用完即丟**：使用 `--rm`，離開時容器自動移除。`sdk/` 內的檔案在主機上，不會消失；
  但你在容器內對系統做的修改（例如額外 `apt install` 的套件）不會保留，下次啟動是乾淨環境。
  需要長期存在的套件請加進 `dockerfiles/Dockerfile.unified` 重新 build。
- **本機只保留一份 image**：拉下來的 image 會另外標記成 `openchan-local/<platform>-<os>:current`，
  之後每次啟動都用這個固定名稱，不會跟你自己 build 的 image 混淆。加 `-u` 更新時會把被
  替換掉的舊版本一併清掉。
- **不修改、也不覆蓋 image 內建的 `entrypoint.sh`**：容器內跑的就是 image 裡那一份，
  與 Docker Hub 上已發布的版本完全一致，行為可預期。
- **不掛載 `~/.ssh` 與 `~/.gitconfig`**：SDK 源碼包當靜態內容處理，不預期在容器內做
  `git pull` 或 `repo sync`。
- **預設不加 `--privileged`**：Yocto（pseudo）與 OpenWrt（fakeroot）設計上都不需要 root，
  產生 image 用的 `mksquashfs`／`mkfs.ext4`／`ubinize` 也都是純使用者空間工具。
  只有在編譯流程真的需要 loop mount 之類的操作時，才加 `--privileged`。
- **拒絕在 Windows 檔案系統上執行**：若 repo 放在 WSL 掛載的 `/mnt/c/...` 之類路徑，
  UID/GID 權限對應會失效、編譯 I/O 也會慢到不可接受，腳本會直接中止並要求你把 repo
  移到 Linux 原生檔案系統。

### `sdk/` 的擁有者

正常情況下 `sdk/` 是你自己建立的，容器內使用者又與主機同 UID/GID（`run-image.sh` 會帶入
`LOCAL_UID`／`LOCAL_GID`／`LOCAL_USER`），權限天生就是對的，不需要任何額外動作。

只有當你用 `sudo` 解開 SDK 壓縮檔、導致檔案屬於 root 時才會不一致。這時 `run-image.sh`
會對頂層 `sdk/` 做一次 `stat`（不掃描整棵樹）並印出提示，但**不會自動修改任何檔案**：

```text
[WARN] sdk/ 的擁有者是 0:0，與目前使用者 1000:1000 不符（通常是用 sudo 解壓縮造成的）。
[WARN] 容器內對這些檔案的寫入可能會失敗。本腳本不會自動修改權限；
[WARN] 確認無誤後，可在容器內自行處理（容器內有免密碼 sudo），並依需要縮限到單一 SDK 目錄：
[WARN]     sudo chown -R $(id -u):$(id -g) /sdk/<你要編譯的那一份>
```

要不要處理、以及處理到什麼範圍，由你自己決定——這正是掛在 `/sdk` 而非 `~/sdk` 換來的
控制權。因為可以縮限到單一子目錄，`sdk/` 底下同時放多個平台 SDK 也不會互相影響。

## 手動使用預建 image

不想用 `run-image.sh`、想自己掌握每個參數時，可以直接操作 docker。
先從 Docker Hub 拉取對應平台的 image，例如 SDX8x：

```bash
docker pull bradlu4/ub2204-quecopen-sdx8x-img:260528
```

> 這一節沿用既有的 `~/sdk` 掛載約定。掛在這個路徑時，`entrypoint.sh` 會在每次啟動時對
> 它做一次遞迴 `chown`（見〈[SDK 放哪裡](#sdk-放哪裡)〉的說明）。若你的 SDK 樹很大、
> 或內含帶 setuid 的預解開 rootfs，改掛到 `~/sdk` 以外的路徑（例如 `-v "$HOME/sdk:/sdk"`）
> 即可跳過該行為，這也是 `run-image.sh` 採用的做法。

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

`dockerfiles/Dockerfile.unified` 將 `dockerfiles/` 下各平台獨立的 Dockerfile 整合成一份，透過 `PLATFORM`／`OS_VERSION`／`VARIANT` build args 切換平台與 dev/CI 變體，方便日後只需維護一份套件清單。原本的平台別 Dockerfile（目前 14 份）仍保留、可繼續使用，兩種方式並存。

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

支援的平台代號：`asr1806`、`asr1903`、`sdx35`、`sdx6x`、`sdx7x`、`sdx8x`、`t830`、`v620`、`vscode`。只有 `t830` 需要用 `-o` 指定 Ubuntu 版本（`ub1804` 或 `ub2204`）；只有 `sdx7x`／`sdx8x`／`t830` 支援 `-v ci`。預設 tag 命名規則為 `<os_version>-quecopen-<platform>-sdk[-ci]`，如需對齊 Docker Hub 既有名稱可用 `-t` 覆蓋。

Build 完成後的啟動方式與上方「快速開始」相同，將 image 名稱換成建置出來的 tag 即可。

## 專案內容

| 檔案 | 用途 |
| --- | --- |
| `run-image.sh` | 選平台 → 取得 image → 掛載 `sdk/` → 直接進入容器 bash 的啟動腳本（dev 用途） |
| `build-image.sh` | 依平台代號呼叫 `dockerfiles/Dockerfile.unified` 產生 image 的建置腳本 |
| `platforms.sh` | 平台矩陣的**單一事實來源**：base image、OS 代號、支援的 variant、Docker Hub image 對照表；`build-image.sh` 與 `run-image.sh` 共用 |
| `sdk/` | SDK 源碼包放置目錄（不進版控），`run-image.sh` 會把它掛到容器內的 `~/sdk` |
| `dockerfiles/Dockerfile.unified` | 整合所有平台的統一 Dockerfile，搭配 `build-image.sh` 與 `PLATFORM`/`OS_VERSION`/`VARIANT` build args 使用 |
| `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` | ASR1806 SDK 編譯環境，Ubuntu 16.04 |
| `dockerfiles/dockerfile-quecopen-asr1903-sdk-ub2004` | ASR1903 SDK 編譯環境，Ubuntu 20.04 |
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
- 若 `/home/<user>/sdk` 這個目錄存在，對它做一次遞迴 `chown`。注意這一段是由
  `if [ -d "/home/${USER_NAME}/sdk" ]` 守著的，**只在 volume 剛好掛在這個約定路徑時才作用**；
  掛在其他路徑（例如 `run-image.sh` 用的 `/sdk`）就會整段跳過。
- 最後使用 `gosu` 切換到該使用者執行命令。`HOME` 由 gosu 依 `passwd` 設定，
  外部用 `-e HOME=...` 傳入的值會被覆蓋。

> `entrypoint.sh` 的內容自 2025-09-16 起未再變動，與 Docker Hub 上所有已發布 image 內的
> 版本一致。修改它會讓 repo 與既有 image 產生分歧，除非同時重新建置並發布全部 image，
> 否則請維持這份檔案不動。可用以下指令驗證：
>
> ```bash
> docker run --rm bradlu4/ub2204-quecopen-sdx8x-img:260528 cat /usr/local/bin/entrypoint.sh \
>   | diff - dockerfiles/entrypoint.sh && echo IDENTICAL
> ```

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
- `script-dev/` 目前標示為開發中，建議優先使用 `run-image.sh`。`script-dev/run-sdk-build.sh` 有兩個已知問題：它用 `groups | grep docker` 判斷權限，在 rootless Docker、Docker Desktop WSL integration 或 root 使用者下會誤判；而且 `docker run` 時沒有帶 `LOCAL_UID`／`LOCAL_GID`／`LOCAL_USER`，後續卻用 `docker exec --user $(id -un)`，主機帳號名稱不是預設值時會失敗。
- 本 repo 必須放在 Linux 原生檔案系統上。放在 WSL 掛載的 Windows 磁碟（`/mnt/c/...`）時，容器的 UID/GID 權限對應會失效、編譯 I/O 也會慢到不可接受，`run-image.sh` 會直接拒絕執行。
- `sdk/` 已列入 `.gitignore`，SDK 源碼包（以及它自帶的 `.git`）不會進入本 repo 的版本控制。
- 實際 SDK 編譯指令仍以各 QuecOpen SDK release package 內的文件為準。
