import SwiftUI

public struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LoginViewModel()
    @State private var isPasswordVisible: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Nền tối hiện đại
            Color(red: 0.05, green: 0.07, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 30)
                    
                    // Logo & Tiêu đề
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                                )
                                .shadow(color: Color.cyan.opacity(0.3), radius: 15)
                            
                            Image(systemName: "fanblades.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("Robot Nội Địa")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Kết nối trực tiếp Ecovacs Deebot từ iPhone\nSiêu nhanh • Không qua server trung gian")
                            .font(.system(size: 13, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    }
                    
                    // Form đăng nhập
                    VStack(spacing: 16) {
                        // Chọn khu vực (Mặc định Trung Quốc)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Khu vực máy chủ")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "globe.asia.australia.fill")
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                Picker("Khu vực", selection: $viewModel.country) {
                                    Text("Trung Quốc (Nội địa - CN)").tag("CN")
                                    Text("Toàn cầu (Quốc tế - WW)").tag("WW")
                                }
                                .pickerStyle(.menu)
                                .tint(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Tài khoản / Số điện thoại
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tài khoản / Số điện thoại")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                TextField("Ví dụ: 16211077946", text: $viewModel.account)
                                    .foregroundColor(.white)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Mật khẩu
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mật khẩu")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.cyan)
                                    .frame(width: 24)
                                
                                if isPasswordVisible {
                                    TextField("Nhập mật khẩu", text: $viewModel.password)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("Nhập mật khẩu", text: $viewModel.password)
                                        .foregroundColor(.white)
                                }
                                
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Thông báo lỗi nếu có
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Nút Đăng nhập
                        Button(action: {
                            viewModel.login {
                                appState.navigateToPicker()
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.cyan, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 52)
                                    .shadow(color: Color.cyan.opacity(0.4), radius: 10, x: 0, y: 4)
                                
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack(spacing: 8) {
                                        Text("Đăng Nhập")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.top, 10)
                        
                        // Thông tin phiên lưu vĩnh viễn
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                            
                            Text("Phiên đăng nhập được lưu vĩnh viễn trên máy cho đến khi bạn bấm Đăng xuất.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                    }
                    .padding(24)
                    .background(Color(red: 0.08, green: 0.11, blue: 0.18))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 30)
                }
            }
        }
    }
}
