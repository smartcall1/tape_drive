#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 초기 설정 함수
setup_environment() {
    echo -e "${YELLOW}Tapedrive 설치 중...${NC}"
    curl -fsSL https://tapedrive.io/install | bash
    source ~/.bashrc

    echo -e "${YELLOW}Solana 키페어 디렉토리 생성 중...${NC}"
    mkdir -p ~/.config/solana

    echo -e "${YELLOW}마이닝 데이터베이스 폴더 생성 중...${NC}"
    mkdir -p ~/db_tapestore
}

# 대시보드 함수
show_dashboard() {
    clear
    echo -e "${GREEN}=== Tapedrive 마이너 대시보드 ===${NC}"
    echo -e "${YELLOW}실행 중인 마이너 수: $1${NC}"
    echo "----------------------------------------"
    for ((i=1; i<=$1; i++)); do
        if ps -p ${PIDS[$i]} > /dev/null; then
            echo -e "${GREEN}마이너 #$i (${MINER_NAMES[$i]}): 실행 중${NC}"
        else
            echo -e "${RED}마이너 #$i (${MINER_NAMES[$i]}): 중지됨${NC}"
        fi
    done
    echo "----------------------------------------"
    echo -e "${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
}

# tapedrive 데이터 등록 함수
write_tapedrive() {
    local miner_num=$1
    local miner_address=$2
    while true; do
        # 5~10분 사이 랜덤 대기
        sleep_time=$((RANDOM % 300 + 300))
        sleep $sleep_time
        tapedrive write -m "hello world!"
        echo "[마이너 #$miner_num] tapedrive 데이터 등록 완료"
    done
}

# 메인 스크립트
echo -e "${YELLOW}Tapedrive 마이너 설정을 시작합니다...${NC}"

# 환경 설정
setup_environment

# 마이너 수 입력
echo -e "${YELLOW}실행할 마이너의 수를 입력하세요: ${NC}"
read miner_count

# 마이너 주소 저장 파일 생성
echo "마이너 주소 목록:" > miner_addresses.txt

# 각 마이너에 대한 PID와 이름 저장 배열
declare -A PIDS
declare -A MINER_NAMES
declare -A MINER_ADDRESSES

# 마이너 등록 및 실행
for ((i=1; i<=$miner_count; i++)); do
    echo -e "${YELLOW}마이너 #$i의 이름을 입력하세요: ${NC}"
    read miner_name
    MINER_NAMES[$i]=$miner_name
    
    echo -e "${YELLOW}마이너 #$i 등록 중...${NC}"
    miner_address=$(tapedrive register "$miner_name")
    MINER_ADDRESSES[$i]=$miner_address
    
    # 마이너 주소를 파일에 저장
    echo "마이너 #$i (${miner_name}) 주소: $miner_address" >> miner_addresses.txt
    
    # 마이너 실행
    echo -e "${YELLOW}마이너 #$i 시작 중...${NC}"
    tapedrive mine "$miner_address" &
    PIDS[$i]=$!
    
    # tapedrive 데이터 등록 프로세스 시작
    write_tapedrive $i "$miner_address" &
    PIDS[$i]=$!
    
    echo -e "${GREEN}마이너 #$i가 시작되었습니다.${NC}"
    echo -e "${YELLOW}주의: devnet SOL이 필요합니다. https://faucet.solana.com/ 에서 충전해주세요.${NC}"
    sleep 2
done

# 대시보드 업데이트
while true; do
    show_dashboard $miner_count
    sleep 5
done 