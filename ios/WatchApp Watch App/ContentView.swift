//
//  ContentView.swift
//  WatchApp Watch App
//
//  Created by 김덕원 on 4/8/26.
//

import SwiftUI

struct ContentView: View {
    // 데이터 매니저 연결 (자동으로 업데이트 감지)
    @StateObject var scoreManager = ScoreManager()
    
    var body: some View {
        VStack(spacing: 8) {
            // 상단 정보 (ScoreManager에서 데이터 가져옴)
            HStack {
                Text(scoreManager.status)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 4)
                    .background(Color.red)
                    .cornerRadius(4)
                Spacer()
                Text(scoreManager.inning)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // 점수판 메인
            HStack(spacing: 12) {
                // 홈팀
                VStack {
                    Image(scoreManager.homeLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                    
                    Text("\(scoreManager.homeScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                
                Text(":")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gray)
                
                // 어웨이팀
                VStack{
                    Image(scoreManager.awayLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                    
                    Text("\(scoreManager.awayScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
        }
        .padding()
    }
 
}

#Preview {
    ContentView()
}
