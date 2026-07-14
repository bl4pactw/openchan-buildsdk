# 變更紀錄（Changelog）

本檔案記錄專案的重要變更。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。

## [Unreleased]

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
