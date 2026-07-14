---
name: quecopen-docker
description: Build, pull, and run QuecOpen SDK compilation-environment Docker images for any hardware platform (asr1806, asr1903, sdx35, sdx6x, sdx7x, sdx8x, t830, v620, vscode) in this openchan repo. Use when someone needs to set up a QuecOpen SDK build environment, choose the right image/tag for a platform, run build-image.sh, docker pull/run a prebuilt image, mount an SDK for compiling, add a new platform to the unified build, or debug a build/run failure (asr1806 pip/pyhocon, UID/GID volume permissions, t830 -o, ci-only platforms, Ninja/GN download).
---

# QuecOpen SDK Docker 環境

這個 repo 為各 QuecOpen SDK 硬體平台提供以 Docker 為基礎的編譯環境。這個 skill 幫助你(或後續的 LLM)為某個平台**選對 image、建置/拉取、並正確啟動掛載 SDK 的容器**,也涵蓋新增平台與疑難排解。

所有指令都在 repo 根目錄 `/home/brad/repo/openchanrepo`(或使用者 clone 的對應路徑)執行。

## 平台對照表(單一事實來源)

| 平台代號 | OS 代號 | Base image | 支援 variant | 需要 `-o`? |
| --- | --- | --- | --- | --- |
| `asr1806` | `ub1604` | ubuntu:16.04 | dev | 否 |
| `asr1903` | `ub2004` | ubuntu:20.04 | dev | 否 |
| `sdx35` | `ub1804` | ubuntu:18.04 | dev | 否 |
| `sdx6x` | `ub1804` | ubuntu:18.04 | dev | 否 |
| `sdx7x` | `ub1804` | ubuntu:18.04 | dev, **ci** | 否 |
| `sdx8x` | `ub2204` | ubuntu:22.04 | dev, **ci** | 否 |
| `t830` | `ub1804` 或 `ub2204`(預設 ub2204) | ubuntu:18.04 / 22.04 | dev, **ci** | **是** |
| `v620` | `ub2004` | ubuntu:20.04 | dev | 否 |
| `vscode` | `ub2204` | ubuntu:22.04 | dev | 否 |

三條規則(常被忽略):
1. **只有 `t830` 需要用 `-o` 指定** `ub1804` 或 `ub2204`;其他平台 OS 版本固定,傳 `-o` 會被忽略(僅警告)。
2. **只有 `sdx7x` / `sdx8x` / `t830` 支援 `-v ci`**;其他平台傳 `ci` 會報錯離開。
3. 預設 tag 命名規則:`<os_version>-quecopen-<platform>-sdk[-ci]`,例如 `ub2204-quecopen-sdx8x-sdk`、`ub1804-quecopen-t830-sdk-ci`。

`dev` 與 `ci` 的差別:`dev` 用 `entrypoint.sh` 依主機 UID/GID 動態建立使用者(適合掛載本機目錄開發);`ci` 用固定 `builder` 帳號(UID/GID 1000)+ `/workspace`(適合 Jenkins)。

## 決策流程:我該怎麼取得環境?

有三條路徑,依需求擇一:

- **只是要用、不改套件 → 直接 `docker pull` 預建 image**(最快)。對照 README 的「Docker Hub 預建鏡像」表找 `bradlu4/...` image 與 tag。
- **要改套件或建內部版本、且平台已支援 → 用 `build-image.sh` 走統一 Dockerfile**(見下方,推薦)。
- **要單獨調某平台、不動統一流程 → 用 `dockerfiles/` 下該平台獨立 Dockerfile 自行 `docker build`**(14 份 legacy Dockerfile 仍保留可用)。

## 建置:build-image.sh(推薦)

```bash
# 語法
./build-image.sh -p <platform> [-o ub1804|ub2204] [-v dev|ci] [-t <custom-tag>]
./build-image.sh -l          # 列出所有支援的平台/os/variant 組合

# 範例
./build-image.sh -p sdx8x                    # SDX8x dev
./build-image.sh -p t830 -o ub1804 -v ci     # T830 Ubuntu 18.04 CI
./build-image.sh -p sdx7x -v ci -t my-img    # 自訂 tag
```

它會依平台自動決定 base image / os_version,再呼叫 `docker build -f dockerfiles/Dockerfile.unified`,build context 是 `dockerfiles/`。開始建置前務必先確認 `docker` 可用且有權限(見疑難排解)。

## 啟動容器

**dev image**(需傳主機 UID/GID/USER,才不會有掛載目錄權限問題):

```bash
mkdir -p "$HOME/sdk"    # 使用者自備:放置第三方 SDK 源碼包
docker run -it --rm \
  -e LOCAL_UID=$(id -u) -e LOCAL_GID=$(id -g) -e LOCAL_USER=$(id -un) \
  -v "$HOME/sdk:/home/$(id -un)/sdk" \
  <image-tag> /bin/bash
```

掛載約定:只掛本地 `$HOME/sdk` 到容器內 `~/sdk`,**不掛整個家目錄**,所以本地與容器的 `.bashrc`/`.ssh` 等互不干擾。這條路徑剛好對上 `entrypoint.sh` 會自動 chown 的 `/home/<user>/sdk`,權限也一致。進容器後在 `~/sdk` 依該 SDK release package 的文件執行原本的 build command;實際編譯指令以各 SDK 文件為準,不在本 skill 範圍。

**ci image**:以固定 `builder` 使用者 + `/workspace` 啟動,不需要 `LOCAL_*` 變數,掛載到 `/workspace` 即可。

## 更深入的任務

- **新增或維護一個平台/變體**(改哪幾個 array、entrypoint 的 dev/ci 分支、Dockerfile.unified 的平台區塊):讀 `references/adding-a-platform.md`。
- **build 或 run 失敗**(asr1806 pyhocon/pip、UID/GID 權限、t830 `-o`、ci 平台限制、Ninja/GN 下載):讀 `references/troubleshooting.md`。

## 關鍵檔案

- `build-image.sh` — 平台代號 → 呼叫 Dockerfile.unified 的建置腳本(平台矩陣的實作在這裡的關聯陣列)
- `dockerfiles/Dockerfile.unified` — 由 `PLATFORM`/`OS_VERSION`/`VARIANT` build args 驅動的統一 Dockerfile
- `dockerfiles/entrypoint.sh` — dev(依主機 UID/GID)與 ci(固定 builder)兩種行為
- `dockerfiles/dockerfile-quecopen-*` — 14 份 legacy 平台別 Dockerfile,與統一流程並存
- `README.md` — 完整的 Docker Hub image 對照表、三種建置方式、注意事項
