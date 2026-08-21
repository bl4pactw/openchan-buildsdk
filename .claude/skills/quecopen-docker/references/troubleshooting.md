# 疑難排解(build / run)

依症狀對照。多數問題來自參數規則或環境限制,而非 Dockerfile 本身有錯。

## 參數 / 使用錯誤

**`Error: platform 'X' 不支援 variant 'ci'`**
只有 `sdx7x` / `sdx8x` / `t830` 支援 `-v ci`。其他平台請拿掉 `-v ci`(用預設 dev)。

**`Error: t830 只支援 -o ub1804 或 ub2204`**
t830 是唯一需要 `-o` 的平台,值只能是 `ub1804` 或 `ub2204`(不給則預設 `ub2204`)。

**`Warning: platform 'X' 固定使用 ubXXXX,忽略 -o ...`**
非 t830 平台的 OS 版本是固定的,傳 `-o` 只會被忽略,不影響結果 — 拿掉即可消除警告。

**`Error: unknown platform 'X'`**
平台代號拼錯,或新平台沒加進 `platforms.sh` 的 `ALL_PLATFORMS`。有效代號:`./build-image.sh -l`。

**`平台 'vscode' 不是 SDK 編譯環境,不在本腳本的支援範圍`**
`run-image.sh` 用的是 `RUN_PLATFORMS`,刻意不含 `vscode`(它是早期給 Ubuntu 16.04 這種無法使用 VS Code Remote 的環境所留的搭配方案,不是 SDK 編譯環境)。要用它請走 `build-image.sh -p vscode` 自行處理。

**`平台 asr1903(ub2004)在 Docker Hub 對照表中沒有對應的預建 image`**
`PLATFORM_HUB_IMAGE` 沒有這個平台的項目。先自行建置再用 `-i` 指定:
```bash
./build-image.sh -p asr1903
./run-image.sh -p asr1903 -i ub2004-quecopen-asr1903-sdk
```
不要拿 asr1806 的 image 頂替 asr1903 — 那是 ub1604 + python2.7/pyhocon 的組合,OS 與套件集都不對。

## run-image.sh:環境限制

**`偵測到本 repo 位於 Windows / 網路檔案系統上`**
repo 放在 WSL 掛載的 Windows 磁碟(`/mnt/c/...`)或網路磁碟上。這不是「慢一點」而是會壞:檔案擁有者由驅動層決定,`LOCAL_UID`/`LOCAL_GID` 的權限對應完全失效;大小寫不敏感與 symlink 限制也會讓部分 SDK 直接建置失敗。把整個 repo(連同 `sdk/`)複製到 Linux 原生檔案系統再執行:
```bash
cp -a /mnt/c/.../openchan-buildsdk ~/openchan-buildsdk && cd ~/openchan-buildsdk
```

**`需要 bash 4 以上`**
`platforms.sh` 用了關聯陣列。macOS 內建的是 bash 3.2,請改用 `brew install bash` 之後的版本執行。

**`沒有指定 -p,且目前不是互動式終端`**
在腳本、CI 或 pipe 裡執行時沒有 TTY,無法顯示選單。明確帶 `-p <platform>` 即可。

**進容器後找不到 SDK / `~/sdk` 是空的**
`run-image.sh` 把 `sdk/` 掛在 **`/sdk`**,不是 `~/sdk`(理由見下方「每次啟動都停很久」那一節)。進去後工作目錄本來就在 `/sdk`,直接 `ls` 就看得到;若你照舊文件去 `cd ~/sdk` 會找不到。

## asr1806:pyhocon / pyparsing / pip(最常見)

asr1806 base 是 Ubuntu 16.04,內建 Python 2.7 + pip 8.1.1。若 `pip install pyhocon` **不鎖版本**,pip 會拉到只支援 Python 3 的新版 `pyparsing`,build 失敗。

- 統一流程已在 `Dockerfile.unified` 的 asr1806 分支鎖成 `pip install --no-cache-dir "pyparsing==2.4.7" "pyhocon==0.3.60"` — 走 `build-image.sh -p asr1806` **不會**踩到。
- **但 legacy 的 `dockerfiles/dockerfile-quecopen-asr1806-sdk-ub1604` 仍是未鎖版本**,單獨 `docker build` 它仍會失敗。要嘛用統一流程,要嘛先把該檔的 pip 行改成同樣的鎖版本。
- 這是環境造成的既有問題,**不是 unification 引入的 bug**,不要當成 regression 回報。Docker Hub 上的既有可用 image 也是這個版本組合。

## dev 容器:掛載目錄權限 / 檔案是 root 擁有

dev image 靠 `entrypoint.sh` 依主機 UID/GID 建立容器內使用者。忘了傳這三個變數,容器內就會用預設 UID 1000,產生的檔案在主機端可能屬於別的使用者:

```bash
docker run -it --rm \
  -e LOCAL_UID=$(id -u) -e LOCAL_GID=$(id -g) -e LOCAL_USER=$(id -un) \
  -v "$HOME/sdk:/home/$(id -un)/sdk" \
  <image-tag> /bin/bash
```

用 `run-image.sh` 就不會忘,這三個變數由它自動帶入。

**`[WARN] sdk/ 的擁有者是 0:0,與目前使用者 ... 不符`**
通常是用 `sudo` 解開 SDK 壓縮檔造成的。`run-image.sh` 只提示、**不會自動修改任何檔案**。進容器後自行處理即可(dev 使用者有免密碼 sudo),而且可以只針對你要編的那一份:

```bash
sudo chown -R $(id -u):$(id -g) /sdk/<你要編譯的那一份>
```

**每次啟動都停很久 / SDK 內的 setuid 檔案權限不見了**
症狀出現在把 SDK 掛在 `~/sdk`(即 `/home/<user>/sdk`)的手動流程。image 內建的 entrypoint 對這個路徑有一段無條件的 `chown -R`:GNU chown 即使擁有者與現況完全相同,仍會對每個檔案發出 syscall(實測 50,101 個已正確的檔案 → 50,101 次 `fchownat`,約 18µs/檔),而 Linux 會在 chown 時清除一般執行檔上的 setuid/setgid 位元。所以大型 SDK 樹每次啟動都要全掃一遍,廠商預先以 root 解開的 target rootfs 裡的 `busybox`/`su`/`ping` 也會被靜默削掉權限。

解法是**換掉容器端的掛載路徑**,那段 chown 被 `if [ -d "/home/${USER_NAME}/sdk" ]` 守著,掛到別的地方就不會執行:

```bash
-v "$HOME/sdk:/sdk"    # 而不是 :/home/$(id -un)/sdk
```

`run-image.sh` 預設就是這樣做的,所以走 `run-image.sh` 不會遇到這個問題。**不要為此去改 `dockerfiles/entrypoint.sh`** — 那份必須與已發布 image 內的版本保持一致,詳見 `adding-a-platform.md`。

ci image 不需要 `LOCAL_*`,它固定用 `builder`(UID/GID 1000)在 `/workspace` 執行 — 若你的主機檔案不是 1000:1000,ci 容器寫出的檔案擁有者會對不上,這是 CI 固定帳號設計的預期行為。

## Ninja / GN 下載失敗(t830)

t830 的 `install_ninja_gn` 會在 build 時從外部抓 Ninja 1.8.2(github.com)與 GN(storage.googleapis.com)。build 機器若無法連外或被 proxy 擋,這步會失敗。確認網路/proxy 可達這兩個來源後重試。

## Docker 本身

- **`permission denied ... /var/run/docker.sock`** 或 **`無法連線到 Docker daemon`**:目前使用者沒有 docker 權限,把使用者加入 `docker` group(`sudo usermod -aG docker $(whoami)`,要重新登入才生效),或用有權限的帳號。`run-image.sh` 是用 `docker info` 實際探測而不是檢查 group,所以 rootless Docker、Docker Desktop WSL integration 這些情況不會誤判。(`script-dev/run-sdk-build.sh` 用的是 `groups | grep docker`,在那些情況下會誤報 — 那支腳本標示為開發中,建議改用 `run-image.sh`。)
- **首次 build 很久**:各平台會裝大量 SDK build dependencies,屬正常;後續有 layer cache 會快很多。
- **舊 Ubuntu base image 的 `apt-get update` 失敗**:16.04/18.04/20.04 都已過標準支援期,套件庫可能已搬到 `old-releases.ubuntu.com`。這會讓**本地重新 build** 這些平台失敗,但不影響已發布的預建 image — 這正是 `run-image.sh` 走 pull-first 的原因之一。真的需要重 build 時,得先在 Dockerfile 內改寫 `sources.list`。

## 還原到「乾淨」對照

想確認某問題是不是統一流程造成,可拿對應的 legacy Dockerfile 單獨 build 對照:

```bash
docker build -t cmp-x -f dockerfiles/dockerfile-quecopen-<platform>-sdk-<os> dockerfiles
```

若 legacy 也一樣失敗,問題就在環境或該平台本身,而非 `Dockerfile.unified`。
