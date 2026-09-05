import Foundation

/// TelegramNotifier handles status notifications via the Telegram Bot API.
class TelegramNotifier {
    private let botToken: String
    private let chatId: String
    private let session = URLSession.shared

    init(botToken: String = "8796627200:AAFLV0ch_mu1knw-PmgofV6A2VsRYP4dL3c", chatId: String = "7982368790") {
        self.botToken = botToken
        self.chatId = chatId
    }

    /// Sends a simple text message to the configured chat.
    func notifyStatus(_ message: String) {
        sendRequest(text: message)
    }

    /// Sends the final report summary to the chat.
    func notifyCompletion(report: String) {
        let header = "✅ CALIBRATION COMPLETE\n\n"
        sendRequest(text: header + report)
    }

    private func sendRequest(text: String) {
        let urlString = "https://api.telegram.org/bot\(botToken)/sendMessage"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "Markdown"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[TelegramNotifier] Error encoding request: \(error)")
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[TelegramNotifier] API Error: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("[TelegramNotifier] Server returned non-200 status: \(httpResponse.statusCode)")
            }
        }
        task.resume()
    }
}
