import Foundation
import WatchConnectivity
import SwiftUI
import Combine

class ScoreManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var homeScore: Int = 0
    @Published var awayScore: Int = 0
    @Published var inning: String = "-"
    @Published var status: String = "-"
    @Published var homeLogo: String = "default_logo"
    @Published var awayLogo: String = "default_logo"
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
   // 아이폰 앱에서 데이터를 보냈을때 호출되는 함수
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            // 받아온 데이터에서 점수를 꺼내기
            if let home = applicationContext["homeScore"] as? Int { self.homeScore = home }
            if let away = applicationContext["awayScore"] as? Int { self.awayScore = away }
            if let inn = applicationContext["inning"] as? String { self.inning = inn }
            if let stat = applicationContext["status"] as? String { self.status = stat }
            if let homeLogo = applicationContext["homeLogo"] as? String { self.homeLogo = homeLogo }
            if let awayLogo = applicationContext["awayLogo"] as? String { self.awayLogo = awayLogo }
            
            print("워치에서 데이터 수신 성공: \(self.homeScore) : \(self.awayScore)")
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
