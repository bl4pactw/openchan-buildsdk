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
平台代號拼錯,或新平台沒加進 `build-image.sh` 的 `ALL_PLATFORMS`。有效代號:`./build-image.sh -l`。

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

entrypoint 只會自動修正 `/home/<user>/sdk` 這個路徑的擁有者;若你掛在別的路徑而遇到權限問題,在容器內用 sudo(dev 使用者有免密碼 sudo)`chown` 或調整掛載點。

ci image 不需要 `LOCAL_*`,它固定用 `builder`(UID/GID 1000)在 `/workspace` 執行 — 若你的主機檔案不是 1000:1000,ci 容器寫出的檔案擁有者會對不上,這是 CI 固定帳號設計的預期行為。

## Ninja / GN 下載失敗(t830)

t830 的 `install_ninja_gn` 會在 build 時從外部抓 Ninja 1.8.2(github.com)與 GN(storage.googleapis.com)。build 機器若無法連外或被 proxy 擋,這步會失敗。確認網路/proxy 可達這兩個來源後重試。

## Docker 本身

- **`permission denied ... /var/run/docker.sock`**:目前使用者沒有 docker 權限,把使用者加入 `docker` group(或用有權限的帳號)。`script-dev/run-sdk-build.sh` 也有同樣需求。
- **首次 build 很久**:各平台會裝大量 SDK build dependencies,屬正常;後續有 layer cache 會快很多。

## 還原到「乾淨」對照

想確認某問題是不是統一流程造成,可拿對應的 legacy Dockerfile 單獨 build 對照:

```bash
docker build -t cmp-x -f dockerfiles/dockerfile-quecopen-<platform>-sdk-<os> dockerfiles
```

若 legacy 也一樣失敗,問題就在環境或該平台本身,而非 `Dockerfile.unified`。
