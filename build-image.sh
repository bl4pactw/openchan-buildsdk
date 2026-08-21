#!/bin/bash
# 依平台代號透過 dockerfiles/Dockerfile.unified 產生對應的 QuecOpen SDK Docker image。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/dockerfiles/Dockerfile.unified"
BUILD_CONTEXT="${SCRIPT_DIR}/dockerfiles"

# 平台矩陣（PLATFORM_BASE_IMAGE / PLATFORM_OS_VERSION / PLATFORM_VARIANTS /
# ALL_PLATFORMS 與 resolve_platform_os、list_platforms 等函式）集中在 platforms.sh，
# 與 run-image.sh 共用同一份定義。新增平台請改 platforms.sh。
# shellcheck source=platforms.sh
. "${SCRIPT_DIR}/platforms.sh"

usage() {
  cat <<EOF
Usage: $0 -p <platform> [-o <os_version>] [-v dev|ci] [-t <tag>]
       $0 -l

  -p, --platform   ${ALL_PLATFORMS// /|}
  -o, --os         Ubuntu 版本代號；只有 t830 需要指定 (ub1804 或 ub2204，預設 ub2204)
  -v, --variant    dev（預設）或 ci；只有 sdx7x/sdx8x/t830 支援 ci
  -t, --tag        自訂 image tag；不指定則用預設命名規則 <os_version>-quecopen-<platform>-sdk[-ci]
  -l, --list       列出所有支援的平台/os/variant 組合後離開
  -h, --help       顯示本說明

Examples:
  $0 -p sdx8x
  $0 -p t830 -o ub1804 -v ci
  $0 -p sdx7x -v ci -t my-sdx7x-ci-img
EOF
}

PLATFORM=""
OS_VERSION=""
VARIANT="dev"
TAG=""

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--platform) PLATFORM="$2"; shift 2 ;;
    -o|--os) OS_VERSION="$2"; shift 2 ;;
    -v|--variant) VARIANT="$2"; shift 2 ;;
    -t|--tag) TAG="$2"; shift 2 ;;
    -l|--list) list_platforms; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$PLATFORM" ]; then
  echo "Error: -p/--platform is required." >&2
  usage
  exit 1
fi

if ! platform_is_valid "$PLATFORM"; then
  echo "Error: unknown platform '$PLATFORM'." >&2
  list_platforms
  exit 1
fi

# 決定 OS_VERSION / BASE_IMAGE（t830 的 -o 特案處理在 platforms.sh 裡）
resolve_platform_os "$PLATFORM" "$OS_VERSION" || exit 1

# 檢查 variant 是否支援
SUPPORTED_VARIANTS="${PLATFORM_VARIANTS[$PLATFORM]}"
case " $SUPPORTED_VARIANTS " in
  *" $VARIANT "*) ;;
  *)
    echo "Error: platform '$PLATFORM' 不支援 variant '$VARIANT'（支援: ${SUPPORTED_VARIANTS}）。" >&2
    exit 1
    ;;
esac

# 預設 tag 命名規則
if [ -z "$TAG" ]; then
  TAG="${OS_VERSION}-quecopen-${PLATFORM}-sdk"
  if [ "$VARIANT" = "ci" ]; then
    TAG="${TAG}-ci"
  fi
fi

echo "[INFO] platform=${PLATFORM} os_version=${OS_VERSION} base_image=${BASE_IMAGE} variant=${VARIANT}"
echo "[INFO] building tag: ${TAG}"

docker build \
  -f "$DOCKERFILE" \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg PLATFORM="$PLATFORM" \
  --build-arg OS_VERSION="$OS_VERSION" \
  --build-arg VARIANT="$VARIANT" \
  -t "$TAG" \
  "$BUILD_CONTEXT"

echo "[INFO] Docker image ${TAG} built successfully."
