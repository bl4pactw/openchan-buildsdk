#!/bin/bash
#
# 取得 QuecOpen SDK 編譯環境並直接進入容器內的 bash（dev 用途）。
#
# 流程：選平台 → 確保本機有對應 image（優先 docker pull 預建 image）→ 掛載 sdk/ →
#       以與主機相同的 UID/GID 進入容器 bash，工作目錄直接落在 ~/sdk。
#
# 設計前提（刻意如此，改動前請先讀 README）：
#   * 只走 dev 路徑。ci variant 是給 Jenkins/CI 用固定 builder 帳號的，
#     不適合互動編譯，請改用 build-image.sh -v ci 自行處理。
#   * SDK 源碼包一律放在本 repo 目錄下的 sdk/，容器內固定掛在 /sdk。
#
#     為什麼是 /sdk 而不是 ~/sdk：image 內建的 entrypoint.sh 有這一段
#         if [ -d "/home/${USER_NAME}/sdk" ]; then
#             chown -R ${USER_ID}:${GROUP_ID} /home/${USER_NAME}/sdk
#         fi
#     那個 chown 是無條件的（GNU chown 即使擁有者相同也會對每個檔案發出 syscall，
#     並清除一般執行檔上的 setuid/setgid 位元），對大型 SDK 樹每次啟動都要付一次
#     全樹掃描的代價，也可能靜默破壞廠商預先解開之 target rootfs 的權限。
#     掛到 /sdk 之後那個 if 條件永遠不成立，整段跳過——不需要修改也不需要覆蓋
#     entrypoint.sh，它與 Docker Hub 上已發布 image 內的版本保持完全一致。
#     權限交由使用者自行掌控（容器內有免密碼 sudo）。
#
#   * 容器用完即丟（--rm）。資料靠 host 端 sdk/ 保存；容器內對系統的修改
#     刻意不保留，避免下次啟動時帶著上次的殘留狀態。
#   * 不掛載 ~/.ssh 與 ~/.gitconfig，SDK 源碼包當靜態內容處理。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=platforms.sh
. "${SCRIPT_DIR}/platforms.sh"

SDK_DIR="${SCRIPT_DIR}/sdk"

# 容器內的掛載點。刻意避開 image 內建 entrypoint.sh 會做遞迴 chown 的
# /home/<user>/sdk，理由見檔案開頭。改這個值之前請先讀懂那段說明。
CONTAINER_SDK="/sdk"

# 本機統一使用的 image 命名空間。用一個專屬前綴，確保不會跟使用者自己 build 的
# image 名稱重疊，也方便 docker images 一眼看出哪些是這支腳本管理的。
LOCAL_NS="openchan-local"
LOCAL_TAG="current"

PLATFORM=""
OS_VERSION=""
IMAGE_OVERRIDE=""
DO_UPDATE=0
USE_PRIVILEGED=0

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die() { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [-p <platform>] [-o ub1804|ub2204] [-i <image>] [-u] [--privileged]
       $0 -l

  -p, --platform    平台代號：${RUN_PLATFORMS// /|}
                    不指定時會列出編號選單讓你挑（需要互動式終端）。
  -o, --os          Ubuntu 版本代號；只有 t830 需要指定（ub1804 或 ub2204，預設 ub2204）。
  -i, --image       直接指定要用的 image，略過 Docker Hub 對照表。
                    用於自行 build 出來的 image，或對照表還沒收錄的平台。
  -u, --update      強制重新 pull 最新 image 並更新本機 image，同時清掉被替換掉的舊版本。
      --privileged  以 --privileged 啟動容器。預設關閉，一般 Yocto/OpenWrt 編譯不需要，
                    只有在編譯流程真的需要 loop mount 之類的操作時才加。
  -l, --list        列出所有支援的平台/os/variant 組合後離開。
  -h, --help        顯示本說明。

Examples:
  $0                        # 互動式選單
  $0 -p sdx8x               # 直接進入 SDX8x 環境
  $0 -p t830 -o ub1804      # T830 指定 Ubuntu 18.04
  $0 -p sdx8x -u            # 更新到最新的 SDX8x image 再進入
  $0 -p asr1903 -i ub2004-quecopen-asr1903-sdk   # 用自行 build 的 image
EOF
}

# --- 前置檢查 ---------------------------------------------------------------------------

check_bash_version() {
  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    die "需要 bash 4 以上（目前是 ${BASH_VERSION}）。macOS 內建的 bash 3.2 不支援關聯陣列，請改用 brew 安裝的 bash 執行。"
  fi
}

# 嚴格拒絕在 Windows 檔案系統上執行。
#
# 若 repo 放在 Windows 磁碟（WSL 底下的 /mnt/c/... 之類），檔案會經由 drvfs/9p 存取：
#   1. 檔案擁有者由驅動層決定，LOCAL_UID/LOCAL_GID 那套權限對應完全失效；
#   2. SDK 編譯這種百萬次小檔存取的情境，I/O 會慢到不可接受；
#   3. 大小寫不敏感與 symlink 限制會讓部分 SDK 直接建置失敗。
# 這些不是「慢一點」而是會產生難以追查的錯誤，所以直接擋掉而不是警告。
check_filesystem() {
  local fstype=""

  if command -v findmnt >/dev/null 2>&1; then
    fstype="$(findmnt -no FSTYPE -T "$SCRIPT_DIR" 2>/dev/null || true)"
  fi
  if [ -z "$fstype" ]; then
    fstype="$(stat -f -c %T "$SCRIPT_DIR" 2>/dev/null || echo unknown)"
  fi

  case "$fstype" in
    9p | drvfs | cifs | smb2 | smb3 | ntfs | ntfs3 | fuseblk | vfat | msdos | exfat)
      die "$(cat <<EOM
偵測到本 repo 位於 Windows / 網路檔案系統上（檔案系統型別：${fstype}）。
    路徑：${SCRIPT_DIR}
    在這種路徑下，容器的 UID/GID 權限對應會失效，編譯 I/O 也會慢到不可接受。
    請把整個 repo（連同 sdk/）移到 Linux 原生檔案系統再執行，例如 WSL 內的 ~/ 底下：
      cp -a "${SCRIPT_DIR}" ~/openchan-buildsdk && cd ~/openchan-buildsdk
EOM
)"
      ;;
  esac

  # 路徑前綴輔助判斷：使用者可能自訂了 WSL 的掛載點，光看檔案系統型別未必抓得到。
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    case "$SCRIPT_DIR" in
      /mnt/[a-z]/* | /[a-z]/*)
        die "偵測到本 repo 位於 WSL 掛載的 Windows 磁碟路徑（${SCRIPT_DIR}）。請移到 WSL 原生檔案系統（例如 ~/）再執行。"
        ;;
    esac
  fi
}

check_docker() {
  command -v docker >/dev/null 2>&1 ||
    die "找不到 docker 指令。請先安裝 Docker Engine 後再執行。"

  # 直接探測 docker 是否可用，而不是檢查使用者在不在 docker group：
  # rootless Docker、Docker Desktop 的 WSL integration、以群組來自 LDAP 的環境，
  # 用 group 判斷都會誤判。
  if ! docker info >/dev/null 2>&1; then
    die "$(cat <<'EOM'
無法連線到 Docker daemon。可能原因：
    1. Docker 服務沒有啟動   → sudo systemctl start docker
    2. 目前使用者沒有權限     → sudo usermod -aG docker $(whoami)
                               （執行後必須重新登入才會生效）
EOM
)"
  fi
}

# --- 平台選擇 ---------------------------------------------------------------------------

hub_ref_for() {
  local platform="$1" os="$2"
  echo "${PLATFORM_HUB_IMAGE[${platform}-${os}]:-}"
}

select_platform_interactive() {
  [ -t 0 ] || die "沒有指定 -p，且目前不是互動式終端，無法顯示選單。請用 -p <platform> 指定平台。"

  local -a menu=()
  local p i=1 os ref mark
  echo "請選擇要使用的平台："
  for p in $RUN_PLATFORMS; do
    menu+=("$p")
    if [ "$p" = "t830" ]; then
      os="ub2204"
    else
      os="${PLATFORM_OS_VERSION[$p]}"
    fi
    ref="$(hub_ref_for "$p" "$os")"
    if [ -n "$ref" ]; then
      mark=""
    else
      mark="  ※ Docker Hub 尚無預建 image，需自行 build 後用 -i 指定"
    fi
    printf "  %2d) %-8s %-8s %s%s\n" "$i" "$p" "$os" "${PLATFORM_DESC[$p]}" "$mark"
    i=$((i + 1))
  done

  local choice
  while :; do
    read -r -p "輸入編號 [1-${#menu[@]}]（直接按 Enter 取消）： " choice || die "讀取輸入失敗。"
    [ -n "$choice" ] || die "已取消。"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#menu[@]}" ]; then
      PLATFORM="${menu[$((choice - 1))]}"
      break
    fi
    echo "  請輸入 1 到 ${#menu[@]} 之間的編號。"
  done

  # t830 是唯一需要選 Ubuntu 版本的平台
  if [ "$PLATFORM" = "t830" ] && [ -z "$OS_VERSION" ]; then
    local os_choice
    echo "t830 需要選擇 Ubuntu 版本："
    echo "   1) ub2204  (Ubuntu 22.04，預設)"
    echo "   2) ub1804  (Ubuntu 18.04)"
    read -r -p "輸入編號 [1-2]（直接按 Enter 用預設）： " os_choice || true
    case "$os_choice" in
      2) OS_VERSION="ub1804" ;;
      *) OS_VERSION="ub2204" ;;
    esac
  fi
}

# --- image 管理 -------------------------------------------------------------------------

image_id_of() {
  docker image inspect -f '{{.Id}}' "$1" 2>/dev/null || true
}

# 移除舊版本 image：只清掉屬於本腳本命名空間、或來自同一個上游 repo 的 tag，
# 不碰使用者自己的 image。使用者要求本機只保留單一版本。
remove_stale_image() {
  local old_id="$1" hub_repo="$2" tag

  while read -r tag; do
    [ -n "$tag" ] || continue
    case "$tag" in
      "${LOCAL_NS}/"* | "${hub_repo}:"*)
        docker rmi "$tag" >/dev/null 2>&1 || true
        ;;
    esac
  done < <(docker image inspect -f '{{range .RepoTags}}{{println .}}{{end}}' "$old_id" 2>/dev/null || true)

  if docker rmi "$old_id" >/dev/null 2>&1; then
    info "已清除被替換掉的舊 image（${old_id:7:12}）。"
  else
    warn "舊 image ${old_id:7:12} 仍被其他 tag 或容器參照，未移除。"
  fi
}

ensure_image() {
  local hub_ref="$1"
  local old_id new_id hub_repo

  old_id="$(image_id_of "$LOCAL_REF")"

  if [ -n "$old_id" ] && [ "$DO_UPDATE" -eq 0 ]; then
    info "重複使用本機既有 image：${LOCAL_REF}"
    return
  fi

  if [ -z "$hub_ref" ]; then
    die "$(cat <<EOM
平台 ${PLATFORM}（${OS_VERSION}）在 Docker Hub 對照表中沒有對應的預建 image。
    請先自行建置，再用 -i 指定：
      ./build-image.sh -p ${PLATFORM}
      $0 -p ${PLATFORM} -i <剛才 build 出來的 image>
EOM
)"
  fi

  if [ "$DO_UPDATE" -eq 1 ]; then
    info "更新 image：${hub_ref}"
  else
    info "本機沒有 ${LOCAL_REF}，開始下載：${hub_ref}"
  fi

  if ! docker pull "$hub_ref"; then
    if [ -n "$old_id" ]; then
      warn "下載 ${hub_ref} 失敗（網路不通或未登入？），改用本機既有的 ${LOCAL_REF} 繼續。"
      return
    fi
    die "下載 ${hub_ref} 失敗，且本機沒有可用的 ${LOCAL_REF}。請確認網路連線後重試。"
  fi

  docker tag "$hub_ref" "$LOCAL_REF"
  new_id="$(image_id_of "$LOCAL_REF")"
  info "已標記為本機固定名稱：${LOCAL_REF}"

  if [ -n "$old_id" ] && [ "$old_id" != "$new_id" ]; then
    hub_repo="${hub_ref%%:*}"
    remove_stale_image "$old_id" "$hub_repo"
  fi
}

# --- sdk/ 目錄 --------------------------------------------------------------------------

ensure_sdk_dir() {
  if [ ! -d "$SDK_DIR" ]; then
    mkdir -p "$SDK_DIR"
    info "已建立 ${SDK_DIR}"
    info "請把 SDK 源碼包放進這個目錄，容器內會掛在 ${CONTAINER_SDK}。"
  fi
}

# 只對頂層 sdk/ 做一次 stat，不掃描整棵樹。
# 本腳本不會自動修改任何檔案的擁有者，只在偵測到不一致時提示；
# 要不要處理、以及要處理到什麼範圍，由使用者自行決定。
check_sdk_owner() {
  local cur_uid cur_gid my_uid my_gid
  cur_uid="$(stat -c %u "$SDK_DIR")"
  cur_gid="$(stat -c %g "$SDK_DIR")"
  my_uid="$(id -u)"
  my_gid="$(id -g)"

  [ "$cur_uid" = "$my_uid" ] && [ "$cur_gid" = "$my_gid" ] && return 0

  warn "sdk/ 的擁有者是 ${cur_uid}:${cur_gid}，與目前使用者 ${my_uid}:${my_gid} 不符（通常是用 sudo 解壓縮造成的）。"
  warn "容器內對這些檔案的寫入可能會失敗。本腳本不會自動修改權限；"
  warn "確認無誤後，可在容器內自行處理（容器內有免密碼 sudo），並依需要縮限到單一 SDK 目錄："
  warn "    sudo chown -R \$(id -u):\$(id -g) ${CONTAINER_SDK}/<你要編譯的那一份>"
}

# --- 啟動容器 ---------------------------------------------------------------------------

run_container() {
  # 不覆蓋、也不修改 image 內建的 entrypoint.sh，讓它與 Docker Hub 上已發布的
  # 版本保持一致。掛載點選在 CONTAINER_SDK（/sdk）而非 /home/<user>/sdk，
  # entrypoint 內那段 `if [ -d "/home/${USER_NAME}/sdk" ]` 的條件因此不成立，
  # 遞迴 chown 整段跳過。
  local -a args=(
    run -it --rm
    --name "openchan-${PLATFORM}-$$"
    --hostname "${PLATFORM}-sdk"
    -e LOCAL_UID="$(id -u)"
    -e LOCAL_GID="$(id -g)"
    -e LOCAL_USER="$(id -un)"
    -e OPENCHAN_PLATFORM="$PLATFORM"
    -v "${SDK_DIR}:${CONTAINER_SDK}"
    -w "${CONTAINER_SDK}"
  )

  if [ "$USE_PRIVILEGED" -eq 1 ]; then
    warn "以 --privileged 啟動：容器內的 root 幾乎等同主機 root，請確認確實有需要。"
    args+=(--privileged)
  fi

  args+=("$LOCAL_REF" /bin/bash)

  echo
  info "平台 ${PLATFORM} / ${OS_VERSION}    image: ${LOCAL_REF}"
  info "主機 ${SDK_DIR}"
  info "  → 容器 ${CONTAINER_SDK}（進入後的工作目錄）"
  info "輸入 exit 離開；容器會在離開時自動移除，sdk/ 內的檔案保留在主機上。"
  echo

  docker "${args[@]}"
}

# --- 主流程 -----------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    -p | --platform) PLATFORM="${2:-}"; shift 2 ;;
    -o | --os) OS_VERSION="${2:-}"; shift 2 ;;
    -i | --image) IMAGE_OVERRIDE="${2:-}"; shift 2 ;;
    -u | --update) DO_UPDATE=1; shift ;;
    --privileged) USE_PRIVILEGED=1; shift ;;
    -l | --list) . "${SCRIPT_DIR}/platforms.sh"; list_platforms; exit 0 ;;
    -h | --help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

check_bash_version
check_filesystem
check_docker

if [ -z "$PLATFORM" ]; then
  select_platform_interactive
fi

if ! platform_is_valid "$PLATFORM"; then
  echo "Error: unknown platform '$PLATFORM'." >&2
  list_platforms
  exit 1
fi

case " $RUN_PLATFORMS " in
  *" $PLATFORM "*) ;;
  *)
    die "平台 '${PLATFORM}' 不是 SDK 編譯環境，不在本腳本的支援範圍（可用：${RUN_PLATFORMS}）。"
    ;;
esac

resolve_platform_os "$PLATFORM" "$OS_VERSION" || exit 1

LOCAL_REF="${LOCAL_NS}/${PLATFORM}-${OS_VERSION}:${LOCAL_TAG}"

if [ -n "$IMAGE_OVERRIDE" ]; then
  [ -n "$(image_id_of "$IMAGE_OVERRIDE")" ] ||
    die "找不到指定的 image：${IMAGE_OVERRIDE}。請先用 ./build-image.sh 建置，或確認名稱是否正確。"
  LOCAL_REF="$IMAGE_OVERRIDE"
  info "使用指定的 image：${LOCAL_REF}（略過 Docker Hub 對照表）"
else
  ensure_image "$(hub_ref_for "$PLATFORM" "$OS_VERSION")"
fi

ensure_sdk_dir
check_sdk_owner
run_container
