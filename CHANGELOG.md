# 變更紀錄（Changelog）

本檔案記錄專案的重要變更。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。

## [Unreleased]

### 2026-08-20 — 新增 run-image.sh：一步進入 SDK 編譯環境

#### 新增（Added）

- `run-image.sh`：選平台（`-p` 或互動式編號選單）→ 取得 image → 掛載 `sdk/` →
  直接進入容器 bash 的啟動腳本。只走 dev 路徑；ci variant 仍由 `build-image.sh -v ci`
  提供，作為客戶自建 CI/CD 流程的參考。
  - **pull-first**：優先使用 Docker Hub 預建 image，拉下來後標記為
    `openchan-local/<platform>-<os>:current`，之後固定使用該名稱，不會與使用者自建的
    image 混淆；本機只保留單一版本，`-u` 更新時會清掉被替換掉的舊 image。
  - `-i/--image` 可略過對照表，直接指定自行 build 出來的 image。
  - 以 `docker info` 實際探測 Docker 是否可用，取代 `groups | grep docker` 的判斷方式
    （後者在 rootless Docker、Docker Desktop WSL integration、root 使用者下會誤判）。
  - 偵測到 repo 位於 Windows／網路檔案系統（drvfs／9p／cifs 等）時直接中止，
    因為該情況下容器的 UID/GID 權限對應會失效、編譯 I/O 也不堪用。
  - 容器以 `--rm` 啟動，用完即丟；不掛載 `~/.ssh` 與 `~/.gitconfig`；
    預設不加 `--privileged`（Yocto/OpenWrt 設計上都不需要 root），保留同名旗標備用。
  - **SDK 掛在容器內的 `/sdk`，而非既有約定的 `~/sdk`**。`entrypoint.sh` 內的遞迴 `chown`
    被 `if [ -d "/home/${USER_NAME}/sdk" ]` 守著，掛到其他路徑該段就不會執行。這讓
    `entrypoint.sh` 得以維持原狀（見下方「維持不變的部分」），同時避開兩個問題：
    GNU chown 即使擁有者與現況完全相同仍會對每個檔案發出 syscall（實測 50,101 個
    已正確的檔案 → 50,101 次 `fchownat`，約 18µs/檔），大型 SDK 樹每次啟動都要全掃一遍；
    以及 Linux 會在 chown 時清除一般執行檔上的 setuid/setgid 位元（root 執行也一樣），
    可能靜默破壞廠商預先以 root 解開之 target rootfs 內 `busybox`／`su`／`ping` 的權限。
  - 對頂層 `sdk/` 做一次 `stat` 檢查擁有者（不掃描整棵樹），不一致時只印提示與可自行執行的
    `sudo chown` 指令，**不會修改任何檔案**。要不要處理、處理到什麼範圍由使用者決定。
- `platforms.sh`：把平台矩陣抽成單一事實來源，`build-image.sh` 與 `run-image.sh` 共用。
  除原有的 `PLATFORM_BASE_IMAGE`／`PLATFORM_OS_VERSION`／`PLATFORM_VARIANTS`／
  `ALL_PLATFORMS` 外，新增 `PLATFORM_HUB_IMAGE`（Docker Hub 對照表，key 為
  `<platform>-<os_version>`）、`PLATFORM_DESC`、`RUN_PLATFORMS`，以及
  `platform_is_valid`／`resolve_platform_os`／`list_platforms` 三個共用函式。
- `.gitignore`：本 repo 先前完全沒有 `.gitignore`。新增後排除 `/sdk/`，
  避免 SDK 源碼包（及其自帶的 `.git`）進入版本控制。

#### 變更（Changed）

- `build-image.sh` 改為 source `platforms.sh`，移除重複的平台矩陣定義。
  對外行為（輸出訊息、退出碼、錯誤處理）與先前完全一致。
- README 由「三種建置方式」改為「四種使用方式」，新增〈一步進入編譯環境〉章節；
  更新 Docker Hub 對照表：asr1806／sdx35／sdx7x／t830 兩版的主要 tag 由 `250909`
  更新為 `250917`，並補上先前未列出的 sdx7x／sdx8x／t830-ub2204 三個 CI image。
- `quecopen-docker` skill 同步更新：SKILL.md 加入 run-image.sh 的決策路徑與行為說明；
  `adding-a-platform.md` 說明平台矩陣已移至 `platforms.sh`、新增 Docker Hub 對照表
  的維護規則；`troubleshooting.md` 新增 run-image.sh 相關症狀與 sdk/ 權限說明。

#### 維持不變的部分（Unchanged by design）

- **`dockerfiles/entrypoint.sh` 一個位元組都沒有改動。** 它被烤進每一個已發布的
  Docker Hub image，內容自 2025-09-16 起未再變動（2026-07-13 那次僅為移入
  `dockerfiles/`，內容不變），因此 repo 這份與所有已發布 image 內的版本一致。
  這是刻意維護的不變式：修改它會讓 repo 與既有 image 分歧，而使用者拉到的是後者。
  需要繞開 entrypoint 的某段行為時，優先讓它的條件不成立（如本次改掛載路徑的做法），
  而不是改檔案。可用以下指令驗證：
  ```bash
  docker run --rm bradlu4/ub2204-quecopen-sdx8x-img:260528 cat /usr/local/bin/entrypoint.sh \
    | diff - dockerfiles/entrypoint.sh && echo IDENTICAL
  ```
- 手動 `docker run` 的既有 `~/sdk` 掛載約定維持不變，README 對應章節照舊；
  只是補上說明：掛在該路徑會保留 entrypoint 的自動 chown 行為，不想要就換掛載點。

#### 已知限制（Known limitations）

- ASR1903 在 Docker Hub 上仍無預建 image，`run-image.sh` 會指引使用者先自行 build
  再用 `-i` 指定。不應借用 ASR1806 的 image（OS 版本與套件集皆不符）。
- `run-image.sh` 與手動 `docker run` 的容器端掛載路徑不同（`/sdk` vs `~/sdk`），
  這是為了讓前者能繞開 entrypoint 的 chown 而刻意保留的差異，README 兩處均已標註。

### 2026-07-14 — 新增 ASR1903 平台

#### 新增（Added）

- `dockerfiles/dockerfile-quecopen-asr1903-sdk-ub2004`：ASR1903 SDK 編譯環境（Ubuntu 20.04，dev），
  套件內容與 V620 相近，Python 改裝 `python2` 與 `python3`。
- `build-image.sh` 與 `dockerfiles/Dockerfile.unified` 新增 `asr1903` 平台
  （`ub2004`，僅支援 dev variant），可用 `./build-image.sh -p asr1903` 建置。

#### 變更（Changed）

- README 同步更新：平台清單、統一建置支援的平台代號、專案內容表新增 asr1903 對應項目。
- `quecopen-docker` skill 同步更新平台對照表與 legacy Dockerfile 數量（13 → 14 份）。
- Docker Hub 目前尚無 ASR1903 預建 image，README 預建鏡像表暫不列入，待發布後再補。

### 2026-07-13 — 統一 Dockerfile 建置與目錄整理

#### 新增（Added）

- `dockerfiles/Dockerfile.unified`：整合各平台獨立的 Dockerfile 為單一份，透過
  `PLATFORM`／`OS_VERSION`／`VARIANT` build args 切換平台與 dev/CI 變體，日後只需維護一份套件清單。
- `build-image.sh`：依平台代號呼叫 `Dockerfile.unified` 一鍵建置對應 image，
  支援 `-p`（平台）、`-o`（Ubuntu 版本，僅 t830 需指定）、`-v`（dev/ci）、`-t`（自訂 tag）、`-l`（列出組合）等參數。
- README 新增〈三種建置方式〉大綱，說明取得／建置 SDK 編譯環境 container 的三種方式：
  1. 使用 Docker Hub 預建 image（`docker pull`）
  2. 從個別平台 Dockerfile 自行 build
  3. 使用統一 Dockerfile + `build-image.sh` 建置
- README 新增〈使用統一 Dockerfile 建置〉章節與專案內容表對應項目。

#### 變更（Changed）

- 將 13 份各平台 Dockerfile、`dockerfile-vscode-common-ub2204` 與 `entrypoint.sh`
  由 repo 根目錄移入 `dockerfiles/` 目錄集中管理（原檔內容不變，維持並存可繼續使用）。
- 更新 README 內所有檔案路徑引用，改指向新的 `dockerfiles/` 位置
  （Docker Hub 對應表、自行 build 指令、專案內容表、`script-dev` 範例）。

#### 維運（Maintenance）

- 更新 git remote `origin` URL 至新位置 `github.com/bl4pactw/openchan-buildsdk`（原為 `openchanrepo`）。
