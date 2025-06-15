#!/bin/bash

TAPEDRIVE_PATH="./tapedrive"
BASE_DIR="/root/tape_nodes"
SOLANA_BIN="$(which solana-keygen)"
KEY_LOG_FILE="${BASE_DIR}/keypairs_summary.txt"

# 🧮 사용자에게 노드 개수 입력받기
read -p "▶ 몇 개의 donemoji 노드를 생성하시겠습니까? (예: 5): " NODE_COUNT

# 유효성 검사
if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
    echo "❌ 올바른 숫자를 입력해주세요. (1 이상)"
    exit 1
fi

# 초기화
mkdir -p "$BASE_DIR"
echo "📄 Tapedrive Keypairs Summary" > "$KEY_LOG_FILE"
echo "Generated at: $(date)" >> "$KEY_LOG_FILE"
echo "===================================" >> "$KEY_LOG_FILE"

# 반복 생성 및 등록
for i in $(seq -w 1 "$NODE_COUNT"); do
    NODE_NAME="donemoji${i}"
    NODE_HOME="${BASE_DIR}/${NODE_NAME}"
    KEYPAIR_PATH="${NODE_HOME}/.config/solana/id.json"

    echo "🔑 [$NODE_NAME] 키 생성 중..."
    mkdir -p "$(dirname "$KEYPAIR_PATH")"
    $SOLANA_BIN new --no-passphrase -o "$KEYPAIR_PATH" > /dev/null 2>&1

    PUBKEY=$($SOLANA_BIN pubkey "$KEYPAIR_PATH")

    echo "🚀 [$NODE_NAME] 등록 중..."
    HOME="$NODE_HOME" "$TAPEDRIVE_PATH" register "$NODE_NAME" <<< "yes"

    # 로그 저장
    echo "[$NODE_NAME]" >> "$KEY_LOG_FILE"
    echo "Path     : $KEYPAIR_PATH" >> "$KEY_LOG_FILE"
    echo "Pubkey   : $PUBKEY" >> "$KEY_LOG_FILE"
    echo "------------------------------" >> "$KEY_LOG_FILE"
done

echo "✅ 총 ${NODE_COUNT}개의 노드 등록 완료!"
echo "📄 키페어 요약 파일 위치: $KEY_LOG_FILE"
