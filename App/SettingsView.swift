import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(SettingsKeys.doubleTapThreshold) private var threshold: Double = 0.4
    @AppStorage(SettingsKeys.primaryTargetCode) private var primaryTargetCode: String = "ko"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let languages: [(code: String, name: String)] = [
        ("ko", "한국어"), ("en", "영어"), ("ja", "일본어"),
        ("zh-CN", "중국어(간체)"), ("es", "스페인어"), ("fr", "프랑스어"),
    ]

    var body: some View {
        Form {
            Picker("기본 대상 언어", selection: $primaryTargetCode) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }

            VStack(alignment: .leading) {
                Text("더블탭 인식 시간: \(threshold, specifier: "%.2f")초")
                Slider(value: $threshold, in: 0.2...0.8, step: 0.05)
            }

            Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        NSLog("cctrans: 로그인 항목 변경 실패 \(error)")
                    }
                }
        }
        .padding(20)
        .frame(width: 380)
    }
}
