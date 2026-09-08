import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Bộ xử lý mã hóa MD5 và tạo chữ ký xác thực Ecovacs API bằng Swift thuần túy
/// Sử dụng Apple CryptoKit bản địa trên iOS 13+ và thuật toán RFC 1321 độc lập
public enum CryptoHelper {
    
    /// Tính chuỗi MD5 hex (lowercase) từ một chuỗi UTF-8
    public static func md5(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return md5(data)
    }
    
    /// Tính chuỗi MD5 hex (lowercase) từ Data
    public static func md5(_ data: Data) -> String {
        #if canImport(CryptoKit)
        if #available(iOS 13.0, macOS 10.15, *) {
            let digest = Insecure.MD5.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        #endif
        return md5RFC1321(data)
    }
    
    private static func md5RFC1321(_ data: Data) -> String {
        var message = Array(data)
        let messageLenBits = UInt64(message.count) * 8
        
        // 1. Padding: thêm byte 0x80
        message.append(0x80)
        
        // 2. Thêm số byte 0 để độ dài (bits) đồng dư với 448 mod 512 (tức là 56 mod 64 bytes)
        while (message.count % 64) != 56 {
            message.append(0)
        }
        
        // 3. Thêm 8 bytes độ dài ban đầu (little-endian)
        for i in 0..<8 {
            message.append(UInt8((messageLenBits >> (i * 8)) & 0xFF))
        }
        
        // 4. Khởi tạo 4 thanh ghi 32-bit (RFC 1321)
        var a: UInt32 = 0x67452301
        var b: UInt32 = 0xEFCDAB89
        var c: UInt32 = 0x98BADCFE
        var d: UInt32 = 0x10325476
        
        // Các hằng số dịch bit
        let s: [UInt32] = [
            7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
            5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
            4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
            6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
        ]
        
        // Bảng hằng số K: K[i] = floor(abs(sin(i + 1)) * (2^32))
        let k: [UInt32] = [
            0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
            0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
            0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
            0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
            0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
            0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
            0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
            0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
            0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
            0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
            0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
            0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
            0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
            0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
            0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
            0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
        ]
        
        // Xử lý từng khối 512 bits (64 bytes)
        let blockCount = message.count / 64
        for bIndex in 0..<blockCount {
            let offset = bIndex * 64
            var m = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 {
                let p = offset + i * 4
                m[i] = UInt32(message[p]) |
                      (UInt32(message[p + 1]) << 8) |
                      (UInt32(message[p + 2]) << 16) |
                      (UInt32(message[p + 3]) << 24)
            }
            
            var aa = a
            var bb = b
            var cc = c
            var dd = d
            
            for i in 0..<64 {
                var f: UInt32 = 0
                var g: Int = 0
                
                if i < 16 {
                    f = (bb & cc) | ((~bb) & dd)
                    g = i
                } else if i < 32 {
                    f = (dd & bb) | ((~dd) & cc)
                    g = (5 * i + 1) % 16
                } else if i < 48 {
                    f = bb ^ cc ^ dd
                    g = (3 * i + 5) % 16
                } else {
                    f = cc ^ (bb | (~dd))
                    g = (7 * i) % 16
                }
                
                let temp = dd
                dd = cc
                cc = bb
                let sum = aa &+ f &+ k[i] &+ m[g]
                let rot = (sum << s[i]) | (sum >> (32 - s[i]))
                bb = bb &+ rot
                aa = temp
            }
            
            a = a &+ aa
            b = b &+ bb
            c = c &+ cc
            d = d &+ dd
        }
        
        let result = [a, b, c, d]
        var hexString = ""
        for word in result {
            for i in 0..<4 {
                let byte = UInt8((word >> (i * 8)) & 0xFF)
                hexString += String(format: "%02x", byte)
            }
        }
        return hexString
    }
    
    /// Tạo chữ ký xác thực Ecovacs API (authSign)
    /// Công thức: MD5(appKey + sorted(key=value) + appSecret)
    public static func generateAuthSign(
        params: [String: Any],
        appKey: String,
        appSecret: String
    ) -> String {
        let sortedKeys = params.keys.sorted()
        var payload = appKey
        for key in sortedKeys {
            if let val = params[key] {
                payload += "\(key)=\(val)"
            }
        }
        payload += appSecret
        return md5(payload)
    }
    
    /// Sinh Hub Device ID ngẫu nhiên hoặc cố định dựa trên tên tài khoản
    public static func generateDeviceId(account: String) -> String {
        let hash = md5(account)
        let prefix = hash.prefix(10)
        return "hub_\(prefix)"
    }
}
