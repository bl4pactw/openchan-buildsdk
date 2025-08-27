#!/bin/bash
set -e

# 預設 UID/GID = 1000，如果外部有帶 LOCAL_UID/LOCAL_GID 就用外部的
USER_ID=${LOCAL_UID:-1000}
GROUP_ID=${LOCAL_GID:-1000}
USER_NAME=${LOCAL_USER:-user}

# 如果 group 不存在就建立
if ! getent group ${GROUP_ID} >/dev/null; then
    groupadd -g ${GROUP_ID} ${USER_NAME}
fi

# 如果 user 不存在就建立
if ! id -u ${USER_ID} >/dev/null 2>&1; then
    useradd --shell /bin/bash -u ${USER_ID} -g ${GROUP_ID} -m ${USER_NAME}
fi

# 確保家目錄存在
mkdir -p /home/${USER_NAME}
chown ${USER_ID}:${GROUP_ID} /home/${USER_NAME}

# 切換到該使用者執行
exec gosu ${USER_NAME} "$@"

