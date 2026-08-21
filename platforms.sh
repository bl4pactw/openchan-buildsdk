# shellcheck shell=bash
#
# QuecOpen SDK Docker 平台矩陣 —— 單一事實來源。
#
# build-image.sh（建置 image）與 run-image.sh（啟動容器）都 source 這個檔案。
# 新增或維護平台時只改這裡，兩支腳本會自動同步。
#
# 需要 bash 4 以上（關聯陣列）。
#
# 本檔案只做定義，不會被直接執行；底下的陣列與變數是給 source 它的腳本使用的。
# shellcheck disable=SC2034

# --- 平台 → base image（t830 除外，t830 靠 -o 決定，見 resolve_platform_os）-------------
declare -A PLATFORM_BASE_IMAGE=(
  [asr1806]="ubuntu:16.04"
  [asr1903]="ubuntu:20.04"
  [sdx35]="ubuntu:18.04"
  [sdx6x]="ubuntu:18.04"
  [sdx7x]="ubuntu:18.04"
  [sdx8x]="ubuntu:22.04"
  [v620]="ubuntu:20.04"
  [vscode]="ubuntu:22.04"
)

# --- 平台 → 固定 OS 代號（t830 除外）----------------------------------------------------
declare -A PLATFORM_OS_VERSION=(
  [asr1806]="ub1604"
  [asr1903]="ub2004"
  [sdx35]="ub1804"
  [sdx6x]="ub1804"
  [sdx7x]="ub1804"
  [sdx8x]="ub2204"
  [v620]="ub2004"
  [vscode]="ub2204"
)

# --- 平台 → 支援的 variant。只有列了 ci，build-image.sh 的 -v ci 才會通過 ---------------
declare -A PLATFORM_VARIANTS=(
  [asr1806]="dev"
  [asr1903]="dev"
  [sdx35]="dev"
  [sdx6x]="dev"
  [sdx7x]="dev ci"
  [sdx8x]="dev ci"
  [t830]="dev ci"
  [v620]="dev"
  [vscode]="dev"
)

# --- <platform>-<os_version> → Docker Hub 上對應的 dev image（含釘死的 tag）-------------
#
# 這張表刻意做成純查表，不從平台代號推導：Docker Hub 上的命名本來就不一致
# （sdx35→x35sdk、sdx6x→x6xsdk、sdx7x→x7xsdk，但 sdx8x→sdx8x），
# 未來要換帳號、換 repo 名稱或改 tag，只要改這裡，不影響腳本邏輯。
#
# tag 一律釘死版本、不要寫 latest（v620 目前上游只有 latest，是唯一例外）。
# 沒有列在這裡的平台代表 Docker Hub 上還沒有對應 image，
# 需要先用 ./build-image.sh 自行建置，再用 run-image.sh -i <image> 指定。
declare -A PLATFORM_HUB_IMAGE=(
  [asr1806-ub1604]="bradlu4/ub1604-quecopen-asr1806sdk-img:250917"
  [sdx35-ub1804]="bradlu4/ub1804-quecopen-x35sdk-img:250917"
  [sdx6x-ub1804]="bradlu4/ub1804-quecopen-x6xsdk-img:250917"
  [sdx7x-ub1804]="bradlu4/ub1804-quecopen-x7xsdk-img:250917"
  [sdx8x-ub2204]="bradlu4/ub2204-quecopen-sdx8x-img:260528"
  [t830-ub1804]="bradlu4/ub1804-quecopen-t830sdk-img:250917"
  [t830-ub2204]="bradlu4/ub2204-quecopen-t830sdk-img:250917"
  [v620-ub2004]="bradlu4/ub2004-quecopen-v620-img:latest"
  # [asr1903-ub2004] 尚未發佈。套件集與 V620 相近（同為 ub2004），
  # 但 asr1903 另外明確安裝 python2 與 python3，不建議直接借用 v620 的 image；
  # 也絕對不要借用 asr1806 的 image（那是 ub1604 + python2.7/pyhocon 的組合）。
)

# --- 平台 → 互動選單顯示的一行說明 ------------------------------------------------------
declare -A PLATFORM_DESC=(
  [asr1806]="ASR1806 SDK"
  [asr1903]="ASR1903 SDK"
  [sdx35]="SDX35 SDK"
  [sdx6x]="SDX6x SDK"
  [sdx7x]="SDX7x SDK"
  [sdx8x]="SDX8x SDK"
  [t830]="T830 SDK（需選 Ubuntu 版本）"
  [v620]="V620 SDK"
  [vscode]="VS Code / common 開發環境（非 SDK 編譯用）"
)

# build-image.sh 認得的全部平台
ALL_PLATFORMS="asr1806 asr1903 sdx35 sdx6x sdx7x sdx8x t830 v620 vscode"

# run-image.sh 選單提供的平台。
# 刻意排除 vscode：它是早期給 Ubuntu 16.04 這種無法使用 VS Code Remote 的環境所留的
# 搭配方案，不是 SDK 編譯環境，放進選單會誤導使用者。
RUN_PLATFORMS="asr1806 asr1903 sdx35 sdx6x sdx7x sdx8x t830 v620"

# --- 共用函式 ---------------------------------------------------------------------------

# 平台代號是否合法
platform_is_valid() {
  case " $ALL_PLATFORMS " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# 解析平台的 OS_VERSION 與 BASE_IMAGE，結果寫入全域變數 OS_VERSION / BASE_IMAGE。
# 用法：resolve_platform_os <platform> [requested_os]
# t830 是唯一需要（也接受）指定 OS 版本的平台，其餘平台傳了只會警告並忽略。
resolve_platform_os() {
  local platform="$1"
  local requested_os="${2:-}"

  if [ "$platform" = "t830" ]; then
    OS_VERSION="${requested_os:-ub2204}"
    case "$OS_VERSION" in
      ub1804) BASE_IMAGE="ubuntu:18.04" ;;
      ub2204) BASE_IMAGE="ubuntu:22.04" ;;
      *)
        echo "Error: t830 只支援 -o ub1804 或 ub2204。" >&2
        return 1
        ;;
    esac
  else
    if [ -n "$requested_os" ] && [ "$requested_os" != "${PLATFORM_OS_VERSION[$platform]}" ]; then
      echo "Warning: platform '$platform' 固定使用 ${PLATFORM_OS_VERSION[$platform]}，忽略 -o $requested_os。" >&2
    fi
    OS_VERSION="${PLATFORM_OS_VERSION[$platform]}"
    BASE_IMAGE="${PLATFORM_BASE_IMAGE[$platform]}"
  fi
}

# 列出所有支援的平台/os/variant 組合
list_platforms() {
  echo "支援的平台:"
  local p
  for p in $ALL_PLATFORMS; do
    if [ "$p" = "t830" ]; then
      echo "  t830      os: ub1804|ub2204 (預設 ub2204)   variant: ${PLATFORM_VARIANTS[$p]}"
    else
      echo "  ${p}      os: ${PLATFORM_OS_VERSION[$p]}   variant: ${PLATFORM_VARIANTS[$p]}"
    fi
  done
}
