# 新增或維護一個平台 / 變體

統一建置流程刻意把「平台矩陣」跟「平台專屬套件」分開,新增平台時要同步改**兩個地方**(有時三個)。改完務必實際 build 驗證。

## 要改哪些檔案

### 1. `build-image.sh`(平台矩陣 — 決定參數合法性與預設值)

檔案頂端有幾個關聯陣列,新增平台 `foo` 時:

- `PLATFORM_BASE_IMAGE[foo]="ubuntu:XX.04"` — 該平台的 base image(**t830 除外**,t830 因為要靠 `-o` 決定 base image,特意不放進這兩個陣列,而是在腳本後段 `if [ "$PLATFORM" = "t830" ]` 特案處理)。
- `PLATFORM_OS_VERSION[foo]="ubXXXX"` — 固定 OS 代號(同樣 t830 除外)。
- `PLATFORM_VARIANTS[foo]="dev"` 或 `"dev ci"` — 支援的變體。**只有這裡列了 `ci`,`-v ci` 才會通過檢查**。
- `ALL_PLATFORMS="... foo"` — 加進這個空白分隔字串,否則 `-p foo` 會被判為 unknown platform。

若新平台像 t830 一樣需要多個 OS 版本可選(要用 `-o`),就得比照 t830 在「決定 OS_VERSION / BASE_IMAGE」那段加特案 `case`,而不是放進固定陣列。

### 2. `dockerfiles/Dockerfile.unified`(平台專屬套件與建置步驟)

在那段大 `case "${PLATFORM}" in ... esac` 裡新增一個 `foo) apt-get install -y ...; ;;` 分支。要點:

- 分支必須以 `;;` 結尾,且每行指令用 `\` 續行(整段是單一 `RUN`)。
- 可重用已定義的 shell function:`install_ninja_gn`(下載 Ninja 1.8.2 + GN,t830 用)、`fix_dash`(把 `/bin/sh` 從 dash 換回 bash)。
- 共用套件(sudo/curl/uuid-dev/flex/bison/locales/gosu、locale、TZ)已在前面統一裝好,分支裡**不用重複**。
- 若該平台要多個 OS 版本,在分支內再依 `${OS_VERSION}` 做 `case`(參考 t830)。
- 內容來源:對照 `dockerfiles/dockerfile-quecopen-foo-*` 那份 legacy Dockerfile 的套件清單搬過來。

### 3. `dockerfiles/entrypoint.sh`(通常不用改)

entrypoint 是平台無關的,只分 dev / ci 兩條路:

- `VARIANT=ci` → `cd /workspace` 後以固定 `builder`(UID/GID 1000,在 Dockerfile.unified 第 128 行建立)執行,不做 host UID/GID 對應。
- 其他(dev)→ 依 `LOCAL_UID`/`LOCAL_GID`/`LOCAL_USER` 動態建立使用者、修 `~/sdk` 權限、給免密碼 sudo,再用 gosu 切換。

只有在你要改變 dev/ci 的啟動行為(例如換工作目錄、換權限策略)時才動它。

## 向後相容的鐵則

- legacy 的 13 份平台別 Dockerfile **不設 `VARIANT`**,entrypoint 因此走 `${VARIANT:-dev}` 的 dev 分支 — 這是刻意的相容設計。改 entrypoint 時**不可破壞未帶 VARIANT 時的 dev 行為**。
- 新增平台**不會**動到既有平台的分支;保持每個平台分支彼此獨立。

## 驗證(必做)

改完至少實跑一次真實 build + run:

```bash
./build-image.sh -p foo                     # 或帶 -o / -v
docker run --rm <built-tag> bash -lc 'gcc --version; echo OK'
```

若新增了 ci 變體,dev 與 ci 各 build 一次。若平台用到 Ninja/GN,確認 build 機器能連外(見 troubleshooting)。
