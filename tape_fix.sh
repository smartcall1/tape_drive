#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 오류 처리 함수
handle_error() {
    echo -e "${RED}오류가 발생했습니다: $1${NC}"
    exit 1
}

# Tapedrive 설치 함수
install_tapedrive() {
    echo -e "${YELLOW}Tapedrive 설치를 시작합니다...${NC}"
    
    # 이전 설치 파일 정리
    rm -f tapedrive-x86_64-linux-musl.tar.gz
    rm -f tapedrive
    
    # Tapedrive 다운로드
    echo -e "${YELLOW}Tapedrive 다운로드 중...${NC}"
    if ! wget https://github.com/spool-labs/tape/releases/download/v0.1.9-alpha/tapedrive-x86_64-linux-musl.tar.gz; then
        handle_error "Tapedrive 다운로드 실패"
    fi
    
    # 압축 해제
    echo -e "${YELLOW}압축 해제 중...${NC}"
    if ! tar -xvzf tapedrive-x86_64-linux-musl.tar.gz; then
        handle_error "압축 해제 실패"
    fi
    
    # 실행 권한 부여
    echo -e "${YELLOW}실행 권한 설정 중...${NC}"
    if ! chmod +x tapedrive; then
        handle_error "실행 권한 설정 실패"
    fi
    
    # 설치 확인
    if [ ! -f "./tapedrive" ]; then
        handle_error "Tapedrive 설치 실패"
    fi
    
    echo -e "${GREEN}Tapedrive 설치가 완료되었습니다.${NC}"
}

# 키페어 디렉토리 생성 함수
create_keypair_dir() {
    local miner_num=$1
    local keypair_dir="/root/.config/solana/miner_${miner_num}"
    
    if ! mkdir -p "$keypair_dir"; then
        handle_error "키페어 디렉토리 생성 실패: $keypair_dir"
    fi
    
    # 기존 키페어 파일이 있다면 백업
    if [ -f "${keypair_dir}/id.json" ]; then
        mv "${keypair_dir}/id.json" "${keypair_dir}/id.json.bak"
    fi
    
    echo "$keypair_dir"
}

# 마이너 등록 함수
register_miner() {
    local miner_num=$1
    local miner_name=$2
    local keypair_dir=$3
    
    # 환경변수로 키페어 경로 설정
    export SOLANA_CONFIG_FILE="${keypair_dir}/config.yml"
    
    # config.yml 파일 생성
    cat > "$SOLANA_CONFIG_FILE" << EOF
json_rpc_url: "https://api.devnet.solana.com"
keypair_path: "${keypair_dir}/id.json"
EOF
    
    # 마이너 등록
    echo -e "${YELLOW}마이너 #$miner_num ($miner_name) 등록 중...${NC}"
    
    # 자동으로 'yes' 응답
    echo "yes" | ./tapedrive register "$miner_name"
    
    # 등록 결과 확인
    if [ $? -ne 0 ]; then
        echo -e "${RED}마이너 등록 실패. devnet SOL이 필요합니다.${NC}"
        echo -e "${YELLOW}https://faucet.solana.com/ 에서 SOL을 충전해주세요.${NC}"
        echo -e "${YELLOW}충전 후 스크립트를 다시 실행해주세요.${NC}"
        exit 1
    fi
}

# 마이너 실행 함수
start_miner() {
    local miner_num=$1
    local miner_name=$2
    local keypair_dir=$3
    
    # 환경변수로 키페어 경로 설정
    export SOLANA_CONFIG_FILE="${keypair_dir}/config.yml"
    
    echo -e "${YELLOW}마이너 #$miner_num ($miner_name) 시작 중...${NC}"
    ./tapedrive mine "$miner_name" &
    local pid=$!
    
    # PID 저장
    echo $pid > "miner_${miner_num}.pid"
    echo $pid
}

# tapedrive 데이터 등록 함수
write_tapedrive() {
    local miner_num=$1
    local miner_name=$2
    local keypair_dir=$3
    
    while true; do
        # 5~10분 사이 랜덤 대기
        sleep_time=$((RANDOM % 300 + 300))
        sleep $sleep_time
        
        # 환경변수로 키페어 경로 설정
        export SOLANA_CONFIG_FILE="${keypair_dir}/config.yml"
        
        ./tapedrive write -m "hello world!"
        date '+%Y-%m-%d %H:%M:%S' > "miner_${miner_num}_last_write.txt"
        echo "[마이너 #$miner_num] tapedrive 데이터 등록 완료"
    done
}

# 대시보드 함수
show_dashboard() {
    clear
    echo -e "${GREEN}=== Tapedrive 마이너 대시보드 ===${NC}"
    echo -e "${YELLOW}실행 중인 마이너 수: $1${NC}"
    echo -e "${BLUE}시스템 시간: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo "----------------------------------------"
    
    for ((i=1; i<=$1; i++)); do
        if [ -f "miner_${i}.pid" ]; then
            pid=$(cat "miner_${i}.pid")
            if ps -p $pid > /dev/null; then
                echo -e "${GREEN}마이너 #$i (${MINER_NAMES[$i]})${NC}"
                echo -e "  키페어 경로: ${KEYPAIR_DIRS[$i]}"
                
                # 마지막 데이터 등록 시간 표시
                if [ -f "miner_${i}_last_write.txt" ]; then
                    last_write=$(cat "miner_${i}_last_write.txt")
                    echo -e "  마지막 데이터 등록: $last_write"
                fi
                
                # CPU 사용량 표시
                cpu_usage=$(ps -p $pid -o %cpu= 2>/dev/null)
                if [ ! -z "$cpu_usage" ]; then
                    echo -e "  CPU 사용량: ${cpu_usage}%"
                fi
                
                # 메모리 사용량 표시
                mem_usage=$(ps -p $pid -o %mem= 2>/dev/null)
                if [ ! -z "$mem_usage" ]; then
                    echo -e "  메모리 사용량: ${mem_usage}%"
                fi
            else
                echo -e "${RED}마이너 #$i (${MINER_NAMES[$i]}): 중지됨${NC}"
            fi
        fi
        echo "----------------------------------------"
    done
    
    echo -e "${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
}

# 메인 스크립트
echo -e "${YELLOW}Tapedrive 마이너 설정을 시작합니다...${NC}"

# Tapedrive 설치
install_tapedrive

# 마이너 수 입력
echo -e "${YELLOW}실행할 마이너의 수를 입력하세요: ${NC}"
read miner_count

# 마이너 정보 저장 배열
declare -A MINER_NAMES
declare -A KEYPAIR_DIRS
declare -A PIDS

# 마이너 등록 및 실행
for ((i=1; i<=$miner_count; i++)); do
    echo -e "${YELLOW}마이너 #$i의 이름을 입력하세요: ${NC}"
    read miner_name
    MINER_NAMES[$i]=$miner_name
    
    # 키페어 디렉토리 생성
    KEYPAIR_DIRS[$i]=$(create_keypair_dir $i)
    
    # 마이너 등록
    register_miner $i "$miner_name" "${KEYPAIR_DIRS[$i]}"
    
    # 마이너 실행
    PIDS[$i]=$(start_miner $i "$miner_name" "${KEYPAIR_DIRS[$i]}")
    
    # tapedrive 데이터 등록 프로세스 시작
    write_tapedrive $i "$miner_name" "${KEYPAIR_DIRS[$i]}" &
    
    echo -e "${GREEN}마이너 #$i가 시작되었습니다.${NC}"
    sleep 2
done

# 대시보드 업데이트
while true; do
    show_dashboard $miner_count
    sleep 5
done 
