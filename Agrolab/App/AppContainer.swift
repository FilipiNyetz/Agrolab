//
//  AppContainer.swift
//  Agrolab
//

import Foundation
import Observation

/// Composição das dependências do app (serviços e sessão).
@MainActor
@Observable
final class AppContainer {
    let environment: AppEnvironment
    let authService: any AuthServicing
    let session: SessionManager

    // AgroBot (UC06): modelo local, voz, conversas e contexto da lavoura.
    let agroBot: AgroBotService
    let voice: VoiceService
    let recentDiagnoses: RecentDiagnosesStore
    let agroBotLauncher = AgroBotLauncher()

    init(environment: AppEnvironment = .current) {
        self.environment = environment

        let client = APIClient(baseURL: environment.apiBaseURL, timeout: environment.requestTimeout)
        let authService = AuthService(client: client, privacyPolicyVersion: environment.privacyPolicyVersion)
        let keychain = KeychainStore(service: "br.com.Agrolab.auth", account: "refresh_token")

        self.authService = authService
        let session = SessionManager(authService: authService, keychain: keychain)
        self.session = session

        let recentDiagnoses = RecentDiagnosesStore()
        let agroBot = AgroBotService(engine: QwenAgroBotEngine(), chats: AgroBotChatStore(), diagnoses: recentDiagnoses)
        self.recentDiagnoses = recentDiagnoses
        self.agroBot = agroBot
        self.voice = VoiceService(recognition: AppleSpeechRecognizer(), synthesis: PiperSpeechSynthesizer())

        // LGPD (RNF-015): ao excluir a conta, as conversas locais do AgroBot também são apagadas.
        session.onAccountDeleted = { [weak agroBot, weak recentDiagnoses] userID in
            try? agroBot?.deleteConversations(ownerID: userID)
            recentDiagnoses?.removeAll()
        }
    }

    func makeAgroBotViewModel(user: User) -> AgroBotViewModel {
        AgroBotViewModel(service: agroBot, voice: voice, user: user)
    }
}
