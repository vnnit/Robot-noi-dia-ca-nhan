import Foundation

public final class EcovacsAuthService {
    public static let shared = EcovacsAuthService()
    
    private let session: URLSession
    private let keychain = KeychainManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Đăng nhập tài khoản trực tiếp (Zero Server)
    public func login(
        account: String,
        passwordOrHash: String,
        country: String = "CN",
        isHash: Bool = false
    ) async throws -> AuthCredentials {
        let pwdHash = isHash ? passwordOrHash : CryptoHelper.md5(passwordOrHash)
        let countryCode = country.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let deviceId = keychain.deviceId
        
        // Bước 1: Gọi API Login lấy UID và AccessToken
        let (uid, accessToken) = try await callLoginApi(
            account: account,
            passwordHash: pwdHash,
            deviceId: deviceId,
            country: countryCode
        )
        
        // Bước 2: Lấy AuthCode
        let authCode = try await callAuthCodeApi(
            uid: uid,
            accessToken: accessToken,
            deviceId: deviceId
        )
        
        // Bước 3: Đổi AuthCode lấy Portal User Token qua loginByItToken
        let (finalUserId, finalToken, expiresAt) = try await callLoginByItToken(
            userId: uid,
            authCode: authCode,
            deviceId: deviceId,
            country: countryCode
        )
        
        let credentials = AuthCredentials(
            userId: finalUserId,
            token: finalToken,
            deviceId: deviceId,
            expiresAt: expiresAt
        )
        
        // Lưu phiên vĩnh viễn trên máy
        keychain.saveSession(
            account: account,
            passwordHash: pwdHash,
            userId: finalUserId,
            token: finalToken,
            expiresAt: expiresAt,
            country: countryCode,
            deviceId: deviceId
        )
        
        return credentials
    }
    
    // MARK: - Tự động gia hạn ngầm (Silent Background Auto-Refresh)
    public func ensureValidToken(force: Bool = false) async throws -> AuthCredentials {
        guard let account = keychain.account,
              let pwdHash = keychain.passwordHash else {
            throw NSError(domain: "EcovacsAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa có thông tin đăng nhập được lưu. Vui lòng đăng nhập lại."])
        }
        
        if !force,
           let token = keychain.token,
           let uid = keychain.userId,
           !token.isEmpty,
           keychain.expiresAt > Int(Date().timeIntervalSince1970) + 300 {
            return AuthCredentials(
                userId: uid,
                token: token,
                deviceId: keychain.deviceId,
                expiresAt: keychain.expiresAt
            )
        }
        
        // Token hết hạn hoặc bắt buộc làm mới (force = true): Gia hạn bằng mật khẩu đã lưu
        return try await login(account: account, passwordOrHash: pwdHash, country: keychain.country, isHash: true)
    }
    
    // MARK: - Bắt buộc làm mới phiên đăng nhập (khi máy chủ Ecovacs báo lỗi 1004)
    public func forceRefreshToken() async throws -> AuthCredentials {
        return try await ensureValidToken(force: true)
    }
    
    // MARK: - Đăng xuất (Chỉ khi người dùng chủ động bấm)
    public func logout() {
        keychain.clearSession()
    }
    
    // MARK: - Chi tiết các bước gọi Ecovacs Cloud Gateway
    private func callLoginApi(
        account: String,
        passwordHash: String,
        deviceId: String,
        country: String
    ) async throws -> (uid: String, accessToken: String) {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let reqId = CryptoHelper.md5("\(Date().timeIntervalSince1970)")
        
        var queryParams: [String: Any] = [
            "account": account,
            "password": passwordHash,
            "requestId": reqId,
            "authTimespan": nowMs,
            "authTimeZone": "GMT-8"
        ]
        
        var signData: [String: Any] = queryParams
        signData["country"] = country.lowercased()
        signData["deviceId"] = deviceId
        signData["lang"] = Constants.defaultLang
        signData["appCode"] = Constants.appCode
        signData["appVersion"] = Constants.appVersion
        signData["channel"] = Constants.channel
        signData["deviceType"] = Constants.deviceType
        
        let authSign = CryptoHelper.generateAuthSign(
            params: signData,
            appKey: Constants.clientKey,
            appSecret: Constants.clientSecret
        )
        queryParams["authSign"] = authSign
        queryParams["authAppkey"] = Constants.clientKey
        
        let path = "/v1/private/\(country.lowercased())/\(Constants.defaultLang)/\(deviceId)/\(Constants.appCode)/\(Constants.appVersion)/\(Constants.channel)/\(Constants.deviceType)/user/loginCheckMobile"
        guard var comp = URLComponents(string: Constants.loginApiBaseUrl + path) else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sai định dạng URL Login"])
        }
        comp.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = comp.url else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw NSError(domain: "EcovacsAuth", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Máy chủ Ecovacs phản hồi lỗi mạng."])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu trả về không hợp lệ"])
        }
        
        guard let code = json["code"] as? String, code == "0000",
              let dataObj = json["data"] as? [String: Any],
              let uid = dataObj["uid"] as? String,
              let accessToken = dataObj["accessToken"] as? String else {
            let msg = json["msg"] as? String ?? "Đăng nhập thất bại. Vui lòng kiểm tra lại tài khoản và mật khẩu."
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        
        return (uid, accessToken)
    }
    
    private func callAuthCodeApi(
        uid: String,
        accessToken: String,
        deviceId: String
    ) async throws -> String {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        var queryParams: [String: Any] = [
            "uid": uid,
            "accessToken": accessToken,
            "bizType": "ECOVACS_IOT",
            "deviceId": deviceId,
            "authTimespan": nowMs
        ]
        
        var signData = queryParams
        signData["openId"] = "global"
        
        let authSign = CryptoHelper.generateAuthSign(
            params: signData,
            appKey: Constants.authClientKey,
            appSecret: Constants.authClientSecret
        )
        queryParams["authSign"] = authSign
        queryParams["authAppkey"] = Constants.authClientKey
        
        guard var comp = URLComponents(string: Constants.openApiBaseUrl + "/v1/global/auth/getAuthCode") else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sai URL AuthCode"])
        }
        comp.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = comp.url else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể tạo URL AuthCode"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String, code == "0000",
              let dataObj = json["data"] as? [String: Any],
              let authCode = dataObj["authCode"] as? String else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể nhận mã uỷ quyền Ecovacs IoT."])
        }
        
        return authCode
    }
    
    private func callLoginByItToken(
        userId: String,
        authCode: String,
        deviceId: String,
        country: String
    ) async throws -> (userId: String, token: String, expiresAt: Int) {
        let portalUrl = Constants.portalUrl(for: country)
        guard let url = URL(string: portalUrl + "/api/users/user.do") else {
            throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sai URL Portal User"])
        }
        
        let body: [String: Any] = [
            "edition": "ECOGLOBLE",
            "userId": userId,
            "token": authCode,
            "realm": Constants.realm,
            "resource": deviceId,
            "org": (country == "CN" ? "ECOCN" : "ECOWW"),
            "last": "",
            "country": (country == "CN" ? "Chinese" : country),
            "todo": "loginByItToken"
        ]
        
        var lastErrorMsg = "Xác thực Portal IT Token thất bại."
        
        for attempt in 1...3 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, _) = try await session.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let result = json["result"] as? String, result == "ok",
                       let token = json["token"] as? String {
                        let finalUid = (json["userId"] as? String) ?? userId
                        let lastDurationMs: Double
                        if let intVal = json["last"] as? Int {
                            lastDurationMs = Double(intVal)
                        } else if let numVal = json["last"] as? NSNumber {
                            lastDurationMs = numVal.doubleValue
                        } else if let strVal = json["last"] as? String, let d = Double(strVal) {
                            lastDurationMs = d
                        } else {
                            lastDurationMs = 604800000.0 // 7 days default
                        }
                        let validitySeconds = (lastDurationMs / 1000.0) * 0.95
                        let expiresAt = Int(Date().timeIntervalSince1970 + validitySeconds)
                        return (finalUid, token, expiresAt)
                    }
                    
                    if let err = json["error"] as? String {
                        lastErrorMsg = "Lỗi máy chủ Ecovacs: \(err)"
                        if err == "set token error." && attempt < 3 {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            continue
                        }
                    }
                }
            } catch {
                lastErrorMsg = error.localizedDescription
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        
        throw NSError(domain: "EcovacsAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: lastErrorMsg])
    }
}
