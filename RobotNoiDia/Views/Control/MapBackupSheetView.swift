import SwiftUI

/// Màn hình Sao Lưu & Khôi Phục Bản Đồ Đa Tầng (Golden Map Backup & Restore)
public struct MapBackupSheetView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var newBackupName: String = ""
    @State private var selectedFloor: String = "Tầng 1"
    @State private var backupToRestore: MapBackupItem? = nil
    @State private var showRestoreConfirm: Bool = false
    
    private let availableFloors = ["Tầng 1", "Tầng 2", "Tầng 3", "Tầng 4"]
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.96, green: 0.97, blue: 0.99)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header mô tả
                        headerBanner
                        
                        // Khung Tạo Bản Sao Lưu Mới
                        createBackupCard
                        
                        // Danh Sách Bản Sao Lưu Hiện Có
                        backupListSection
                        
                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Sao Lưu & Khôi Phục Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        HapticManager.shared.light()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
            }
            .alert("Khôi Phục Bản Đồ", isPresented: $showRestoreConfirm, presenting: backupToRestore) { item in
                Button("Hủy", role: .cancel) {}
                Button("Khôi phục ngay", role: .destructive) {
                    viewModel.restoreMapBackup(item)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: { item in
                Text("Bạn có chắc chắn muốn nạp lại '\(item.name)' cho \(item.floorName)? Robot sẽ tái lập toàn bộ phòng và tường ảo của bản đồ này.")
            }
        }
    }
    
    // MARK: - Banner Header
    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "map.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.teal)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Bảo Vệ Bản Đồ Chuẩn")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                Text("Lưu bản đồ vàng để khôi phục tức thì 1-chạm khi robot bị trượt bánh hoặc loạn map.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
    
    // MARK: - Card Tạo Bản Sao Lưu
    private var createBackupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LƯU BẢN ĐỒ HIỆN TẠI")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.gray)
            
            VStack(spacing: 12) {
                // Chọn Tầng
                HStack {
                    Text("Tầng nhà:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    
                    Spacer()
                    
                    Picker("Tầng", selection: $selectedFloor) {
                        ForEach(availableFloors, id: \.self) { floor in
                            Text(floor).tag(floor)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                }
                
                // Nhập Tên Bản Đồ
                TextField("Tên ghi chú (Ví dụ: Bản đồ T1 chuẩn)", text: $newBackupName)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                    .cornerRadius(10)
                
                // Nút Lưu
                Button(action: {
                    let name = newBackupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.createMapBackup(
                        name: name.isEmpty ? "Bản đồ \(selectedFloor)" : name,
                        floorName: selectedFloor
                    )
                    newBackupName = ""
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Lưu Bản Đồ Hiện Tại")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                    .cornerRadius(10)
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
        }
    }
    
    // MARK: - Danh Sách Backup
    private var backupListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CÁC BẢN SAO LƯU ĐÃ LƯU (\(viewModel.mapBackups.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.gray)
                Spacer()
            }
            
            if viewModel.mapBackups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text("Chưa có bản đồ sao lưu nào")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                    Text("Bấm 'Lưu Bản Đồ Hiện Tại' ở trên để tạo bản sao lưu đầu tiên.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.white)
                .cornerRadius(14)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.mapBackups) { item in
                        backupItemRow(item: item)
                    }
                }
            }
        }
    }
    
    private func backupItemRow(item: MapBackupItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.floorName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(6)
                
                Text(item.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                
                Spacer()
                
                Button(action: {
                    viewModel.deleteMapBackup(id: item.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color.red.opacity(0.8))
                        .padding(6)
                }
            }
            
            HStack(spacing: 12) {
                Label("\(item.rooms.count) phòng", systemImage: "square.split.2x2")
                Label("\(item.virtualWalls.count) tường ảo", systemImage: "line.diagonal")
                Spacer()
                Text(item.formattedDate)
                    .foregroundColor(Color.gray)
            }
            .font(.system(size: 11))
            .foregroundColor(Color.gray)
            
            Divider()
            
            Button(action: {
                HapticManager.shared.medium()
                backupToRestore = item
                showRestoreConfirm = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    Text("Khôi phục bản đồ này")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
    }
}
