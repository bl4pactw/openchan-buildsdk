# 新增或維護一個平台 / 變體

統一建置流程刻意把「平台矩陣」跟「平台專屬套件」分開,新增平台時要同步改**兩個地方**(有時四個)。改完務必實際 build 驗證。

## 要改哪些檔案

### 1. `platforms.sh`(平台矩陣 — 決定參數合法性與預設值)

平台矩陣集中在 repo 根目錄的 `platforms.sh`,`build-image.sh` 與 `run-image.sh` 都 source 它——**只改這一份,兩支腳本會自動同步**。裡面有幾個關聯陣列,新增平台 `foo` 時:

- `PLATFORM_BASE_IMAGE[foo]="ubuntu:XX.04"` — 該平台的 base image(**t830 除外**,t830 因為要靠 `-o` 決定 base image,特意不放進這兩個陣列,而是在腳本後段 `if [ "$PLATFORM" = "t830" ]` 特案處理)。
- `PLATFORM_OS_VERSION[foo]="ubXXXX"` — 固定 OS 代號(同樣 t830 除外)。
- `PLATFORM_VARIANTS[foo]="dev"` 或 `"dev ci"` — 支援的變體。**只有這裡列了 `ci`,`-v ci` 才會通過檢查**。
- `ALL_PLATFORMS="... foo"` — 加進這個空白分隔字串,否則 `-p foo` 會被判為 unknown platform。

若新平台像 t830 一樣需要多個 OS 版本可選(要用 `-o`),就得比照 t830 在 `resolve_platform_os()` 裡加特案 `case`,而不是放進固定陣列。

還有兩個給 `run-image.sh` 用的項目:

- `PLATFORM_DESC[foo]="..."` — 互動選單上顯示的一行說明。
- `RUN_PLATFORMS` — 加進去,`run-image.sh` 才會提供這個平台。**刻意不等於 `ALL_PLATFORMS`**:`vscode` 只在 `ALL_PLATFORMS` 裡,因為它是共用開發環境而非 SDK 編譯環境,放進選單會誤導使用者。

### 2. `platforms.sh` 的 `PLATFORM_HUB_IMAGE`(Docker Hub 對照表)

`run-image.sh` 走 pull-first,靠這張表決定要拉哪個 image:

```bash
[foo-ubXXXX]="bradlu4/<repo>:<tag>"
```

三個規則:

- key 是 `<platform>-<os_version>`,所以 t830 那種多 OS 的平台自然會有兩筆。
- **一定要查表,不要試圖從平台代號推導 repo 名稱**。Docker Hub 上的命名本來就不一致(`sdx35`→`x35sdk`、`sdx6x`→`x6xsdk`、`sdx7x`→`x7xsdk`,但 `sdx8x`→`sdx8x`)。
- **tag 要釘死版本、不要寫 `latest`**,否則使用者本機的「固定 image」會隨上游漂移。(`v620` 目前上游只有 `latest`,是唯一例外。)

沒列進這張表的平台不會壞掉,只是 `run-image.sh` 會告訴使用者先 `build-image.sh` 再用 `-i` 指定。`asr1903` 目前就是這個狀態。**不要把它指到 `asr1806` 的 image 頂替**——那是 ub1604 + python2.7/pyhocon 的組合,跟 asr1903 需要的 ub2004 環境不符。

### 3. `dockerfiles/Dockerfile.unified`(平台專屬套件與建置步驟)

在那段大 `case "${PLATFORM}" in ... esac` 裡新增一個 `foo) apt-get install -y ...; ;;` 分支。要點:

- 分支必須以 `;;` 結尾,且每行指令用 `\` 續行(整段是單一 `RUN`)。
- 可重用已定義的 shell function:`install_ninja_gn`(下載 Ninja 1.8.2 + GN,t830 用)、`fix_dash`(把 `/bin/sh` 從 dash 換回 bash)。
- 共用套件(sudo/curl/uuid-dev/flex/bison/locales/gosu、locale、TZ)已在前面統一裝好,分支裡**不用重複**。
- 若該平台要多個 OS 版本,在分支內再依 `${OS_VERSION}` 做 `case`(參考 t830)。
- 內容來源:對照 `dockerfiles/dockerfile-quecopen-foo-*` 那份 legacy Dockerfile 的套件清單搬過來。

### 4. `dockerfiles/entrypoint.sh`(通常不用改)

entrypoint 是平台無關的,只分 dev / ci 兩條路:

- `VARIANT=ci` → `cd /workspace` 後以固定 `builder`(UID/GID 1000,在 Dockerfile.unified 尾端的 `VARIANT=ci` 分支建立)執行,不做 host UID/GID 對應。
- 其他(dev)→ 依 `LOCAL_UID`/`LOCAL_GID`/`LOCAL_USER` 動態建立使用者、視情況處理 `~/sdk` 擁有者、給免密碼 sudo,再用 gosu 切換。

### 這份檔案原則上不要動

`entrypoint.sh` 被**烤進每一個已發布的 Docker Hub image**,而且內容自 2025-09-16 起未再變動(2026-07-13 那次只是把它搬進 `dockerfiles/`,內容不變)。也就是說 repo 這份與所有已發布 image 內的那份目前是一致的 —— 這是個值得維護的不變式。

改它會讓兩者分歧:repo 是新的,已發布 image 還是舊的,而使用者拉到的是後者。除非你打算同時重新建置並推送全部 image,否則**不要改這份檔案**。可用這個指令驗證一致性:

```bash
docker run --rm bradlu4/ub2204-quecopen-sdx8x-img:260528 cat /usr/local/bin/entrypoint.sh \
  | diff - dockerfiles/entrypoint.sh && echo IDENTICAL
```

### 需要繞開 entrypoint 行為時的做法

`entrypoint.sh` 裡的遞迴 chown 是有條件的:

```bash
if [ -d "/home/${USER_NAME}/sdk" ]; then
    chown -R ${USER_ID}:${GROUP_ID} /home/${USER_NAME}/sdk
fi
```

路徑是寫死的,所以**只要 volume 不掛在 `/home/<user>/sdk`,整段就不會執行**。`run-image.sh` 正是靠這點:掛到 `/sdk`,不修改也不覆蓋 entrypoint,就避開了那個 chown。要繞開 entrypoint 的其他行為時,優先想「有沒有辦法讓它的條件不成立」,而不是去改檔案。

(第 27 行的 `mkdir -p /home/${USER_NAME}` 只建家目錄本身、第 23 行 `useradd -m` 從 `/etc/skel` 複製骨架,兩者都不會產生 `sdk` 子目錄,所以這個繞法是穩的。)

為什麼要避開那個 chown:GNU chown 即使目標擁有者與現況完全相同,仍會對每個檔案發出 syscall(實測 50,101 個已正確的檔案 → 50,101 次 `fchownat`),而 Linux 會在 chown 時清除一般執行檔上的 setuid/setgid 位元(root 執行也一樣)。後果是每次啟動付一次全樹掃描,加上廠商預先以 root 解開的 target rootfs 可能被靜默破壞。

### 順手記著:HOME 由 gosu 決定

`entrypoint.sh` 第 29 行 `export HOME=${USER_HOME}` 裡的 `USER_HOME` 從未定義,實際是把 `HOME` 設成空字串。沒出事是因為第 42 行的 `gosu` 會先 `os.Unsetenv("HOME")` 再依 passwd 重設。這行是死碼,但基於上述「與 image 保持一致」的理由**維持原狀不要刪**。副作用:外部 `-e HOME=...` 也會被 gosu 覆蓋,無法注入自訂 HOME。

## 向後相容的鐵則

- legacy 的 14 份平台別 Dockerfile **不設 `VARIANT`**,entrypoint 因此走 `${VARIANT:-dev}` 的 dev 分支 — 這是刻意的相容設計。萬一真的非改 entrypoint 不可,**不可破壞未帶 VARIANT 時的 dev 行為**。
- `entrypoint.sh` 與已發布 image 內的版本一致,是刻意維護的不變式(見上一節)。
- 新增平台**不會**動到既有平台的分支;保持每個平台分支彼此獨立。

## 驗證(必做)

改完至少實跑一次真實 build + run:

```bash
./build-image.sh -p foo                     # 或帶 -o / -v
docker run --rm <built-tag> bash -lc 'gcc --version; echo OK'
./run-image.sh -p foo -i <built-tag>        # 確認能一路進到容器 bash
```

改過 `platforms.sh` 之後,順手確認 `build-image.sh` 的行為沒被連累:

```bash
./build-image.sh -l
./build-image.sh -p t830 -o ub1804 -v ci    # t830 特案 + ci 檢查
./build-image.sh -p v620 -v ci              # 應該報錯:v620 不支援 ci
```

若新增了 ci 變體,dev 與 ci 各 build 一次。若平台用到 Ninja/GN,確認 build 機器能連外(見 troubleshooting)。
