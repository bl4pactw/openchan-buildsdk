#!/bin/bash
# 依平台代號透過 dockerfiles/Dockerfile.unified 產生對應的 QuecOpen SDK Docker image。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/dockerfiles/Dockerfile.unified"
BUILD_CONTEXT="${SCRIPT_DIR}/dockerfiles"

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
ALL_PLATFORMS="asr1806 asr1903 sdx35 sdx6x sdx7x sdx8x t830 v620 vscode"

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

list_platforms() {
  echo "支援的平台:"
  for p in $ALL_PLATFORMS; do
    if [ "$p" = "t830" ]; then
      echo "  t830      os: ub1804|ub2204 (預設 ub2204)   variant: ${PLATFORM_VARIANTS[$p]}"
    else
      echo "  ${p}      os: ${PLATFORM_OS_VERSION[$p]}   variant: ${PLATFORM_VARIANTS[$p]}"
    fi
  done
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

case " $ALL_PLATFORMS " in
  *" $PLATFORM "*) ;;
  *)
    echo "Error: unknown platform '$PLATFORM'." >&2
    list_platforms
    exit 1
    ;;
esac

# 決定 OS_VERSION / BASE_IMAGE
if [ "$PLATFORM" = "t830" ]; then
  OS_VERSION="${OS_VERSION:-ub2204}"
  case "$OS_VERSION" in
    ub1804) BASE_IMAGE="ubuntu:18.04" ;;
    ub2204) BASE_IMAGE="ubuntu:22.04" ;;
    *)
      echo "Error: t830 只支援 -o ub1804 或 ub2204。" >&2
      exit 1
      ;;
  esac
else
  if [ -n "$OS_VERSION" ] && [ "$OS_VERSION" != "${PLATFORM_OS_VERSION[$PLATFORM]}" ]; then
    echo "Warning: platform '$PLATFORM' 固定使用 ${PLATFORM_OS_VERSION[$PLATFORM]}，忽略 -o $OS_VERSION。" >&2
  fi
  OS_VERSION="${PLATFORM_OS_VERSION[$PLATFORM]}"
  BASE_IMAGE="${PLATFORM_BASE_IMAGE[$PLATFORM]}"
fi

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
