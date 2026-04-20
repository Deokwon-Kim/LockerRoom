import cv2
import mss
import numpy as np
import easyocr
import time
import re

KBO_TEAMS = ['삼성', '롯데', '두산', 'KT', '키움', '한화', 'LG', 'SSG', 'NC', 'KIA']

def parse_horizontal_scorebar(results):
    sorted_res = sorted(results, key=lambda x: x[0][0][0]) 
    data = {"status": "예정", "team1": "", "score1": 0, "team2": "", "score2": 0}
    found_teams, found_scores = [], []
    
    for bbox, text, conf in sorted_res:
        if any(x in text for x in ['회', '초', '말', '경기', '종료', '예정', '취소']):
            data["status"] = text
            continue
        for team in KBO_TEAMS:
            if team in text:
                found_teams.append((bbox[0][0], team))
                break
        num_str = re.sub(r'[^0-9]', '', text)
        if num_str and len(num_str) <= 2:
            found_scores.append((bbox[0][0], int(num_str)))

    if len(found_teams) >= 2:
        data["team1"], data["team2"] = found_teams[0][1], found_teams[-1][1]
        t1_x, t2_x = found_teams[0][0], found_teams[-1][0]
        for s_x, val in found_scores:
            if abs(s_x - t1_x) < abs(s_x - t2_x): data["score1"] = val
            else: data["score2"] = val
    return data

def score_tracking():
    # GPU 대신 CPU 환경에서도 안정적인 옵션 추가
    reader = easyocr.Reader(['ko', 'en'], gpu=True) 
    game_areas = []
    
    with mss.mss() as sct:
        monitor = sct.monitors[1]
        screenshot = np.array(sct.grab(monitor))
        screenshot = cv2.cvtColor(screenshot, cv2.COLOR_BGRA2BGR)
        
        print("📸 가로형 전광판을 시원시원하게 큼직하게 드래그해 주세요!")
        for i in range(5):
            roi = cv2.selectROI(f"Select Game {i+1}", screenshot, False)
            cv2.destroyWindow(f"Select Game {i+1}")
            if roi[2] == 0: break
            game_areas.append({"top": int(monitor["top"] + roi[1]), "left": int(monitor["left"] + roi[0]), "width": int(roi[2]), "height": int(roi[3])})

        confirmed_data = [None] * len(game_areas)
        pending_data = [None] * len(game_areas)
        match_count = [0] * len(game_areas)
        finished_mask = [False] * len(game_areas)

        print("\n🚀 전처리 강화 모드 시작 (7 vs 5 오독 집중 케어)")
        
        while True:
            for idx, area in enumerate(game_areas):
                if finished_mask[idx]: continue
                raw = np.array(sct.grab(area))
                img = cv2.cvtColor(raw, cv2.COLOR_BGRA2BGR)
                
                # --- [특수 전처리 시작] ---
                # 1. 2배 확대
                h, w = img.shape[:2]
                img = cv2.resize(img, (w*2, h*2), interpolation=cv2.INTER_LANCZOS4)
                
                # 2. 흑백 전환 및 이미지 반전 (OCR은 흰 배경의 검은 글자를 훨씬 잘 읽습니다)
                gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                # 이진화 작업 (글자를 더 뚜렷하게)
                _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY_INV) 
                
                # 이미지가 너무 검으면 반전 (점수가 흰색일 경우 대비)
                if np.mean(thresh) > 127: thresh = cv2.bitwise_not(thresh)
                # -------------------------

                results = reader.readtext(thresh) # 흑백 이미지로 분석
                current = parse_horizontal_scorebar(results)

                if current["team1"] and current["team2"]:
                    if current == pending_data[idx]:
                        match_count[idx] += 1
                    else:
                        match_count[idx] = 1
                        pending_data[idx] = current

                    if match_count[idx] >= 2:
                        prev = confirmed_data[idx]
                        # 점수 하락 방지 (제일 중요!)
                        if prev and (current["score1"] < prev["score1"] or current["score2"] < prev["score2"]):
                            continue

                        if current != confirmed_data[idx]:
                            confirmed_data[idx] = current
                            print(f"\n📢 [{time.strftime('%H:%M:%S')}] {idx+1}경기 업데이트:")
                            print(f"   ⚾ {current['team1']} {current['score1']} VS {current['score2']} {current['team2']} ({current['status']})")
                            
                            if '종료' in current['status']: finished_mask[idx] = True

            if cv2.waitKey(1) & 0xFF == ord('q'): break
            time.sleep(1.5)

    cv2.destroyAllWindows()

if __name__ == "__main__":
    score_tracking()
