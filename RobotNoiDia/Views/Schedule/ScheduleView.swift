import SwiftUI

public struct ScheduleView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showScheduleEditorSheet: Bool = false
    @State private var selectedScheduleForEdit: CleaningScheduleItem? = nil
    
    public init(viewModel: RobotControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.96, blue: 0.98)
                    .ignoresSafeArea()
                
                if viewModel.state.schedules.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 54))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("Chưa có lịch hẹn giờ dọn dẹp nào")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(white: 0.2))
                        Text("Đặt lịch để DEEBOT tự động dọn nhà vào các khung giờ cố định trong tuần.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            selectedScheduleForEdit = nil
                            showScheduleEditorSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Thêm lịch hẹn giờ")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.09, green: 0.47, blue: 1.0))
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
                        }
                    }
                } else {
                    List {
                        Section(header: Text("Danh sách hẹn giờ tự động")) {
                            ForEach(viewModel.state.schedules) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.timeString)
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundColor(item.isEnabled ? .black : .gray)
                                        
                                        Text(item.label)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(item.isEnabled ? Color(white: 0.2) : .gray)
                                        
                                        HStack(spacing: 6) {
                                            Text(item.repeatDaysText)
                                                .font(.system(size: 12))
                                                .foregroundColor(item.isEnabled ? Color(red: 0.09, green: 0.47, blue: 1.0) : .gray)
                                            
                                            Text("•")
                                                .foregroundColor(.gray.opacity(0.5))
                                                .font(.system(size: 10))
                                            
                                            Text(item.fanSpeed.capitalized)
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { item.isEnabled },
                                        set: { _ in viewModel.toggleSchedule(id: item.id) }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedScheduleForEdit = item
                                    showScheduleEditorSheet = true
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteSchedule(id: item.id)
                                    } label: {
                                        Label("Xóa", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationBarTitle("Lịch Hẹn Giờ Dọn Dẹp", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Đóng") { presentationMode.wrappedValue.dismiss() },
                trailing: Button(action: {
                    selectedScheduleForEdit = nil
                    showScheduleEditorSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.09, green: 0.47, blue: 1.0))
                }
            )
            .sheet(isPresented: $showScheduleEditorSheet) {
                AddScheduleSheet(viewModel: viewModel, existingSchedule: selectedScheduleForEdit)
            }
        }
    }
}

struct AddScheduleSheet: View {
    @ObservedObject var viewModel: RobotControlViewModel
    var existingSchedule: CleaningScheduleItem?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate = Date()
    @State private var labelText = "Hẹn giờ dọn dẹp"
    @State private var repeatDays: Set<Int> = [2, 3, 4, 5, 6] // T2-T6
    @State private var selectedMode = "auto"
    @State private var selectedFan = "standard"
    @State private var selectedWater = 2
    
    let days = [
        (2, "T2"), (3, "T3"), (4, "T4"), (5, "T5"), (6, "T6"), (7, "T7"), (1, "CN")
    ]
    
    init(viewModel: RobotControlViewModel, existingSchedule: CleaningScheduleItem? = nil) {
        self.viewModel = viewModel
        self.existingSchedule = existingSchedule
        
        if let item = existingSchedule {
            var comp = DateComponents()
            comp.hour = item.hour
            comp.minute = item.minute
            let initialDate = Calendar.current.date(from: comp) ?? Date()
            _selectedDate = State(initialValue: initialDate)
            _labelText = State(initialValue: item.label)
            _repeatDays = State(initialValue: Set(item.repeatDays))
            _selectedMode = State(initialValue: item.cleanMode)
            _selectedFan = State(initialValue: item.fanSpeed)
            _selectedWater = State(initialValue: item.waterAmount)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thời gian bắt đầu")) {
                    DatePicker("Giờ bắt đầu", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                
                Section(header: Text("Lặp lại hàng tuần")) {
                    HStack(spacing: 8) {
                        Button("Hàng ngày") {
                            repeatDays = [1, 2, 3, 4, 5, 6, 7]
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(repeatDays.count == 7 ? Color.blue : Color.gray.opacity(0.15))
                        .foregroundColor(repeatDays.count == 7 ? .white : .black)
                        .cornerRadius(6)
                        
                        Button("T2 - T6") {
                            repeatDays = [2, 3, 4, 5, 6]
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(repeatDays.sorted() == [2, 3, 4, 5, 6] ? Color.blue : Color.gray.opacity(0.15))
                        .foregroundColor(repeatDays.sorted() == [2, 3, 4, 5, 6] ? .white : .black)
                        .cornerRadius(6)
                        
                        Button("Cuối tuần") {
                            repeatDays = [1, 7]
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(repeatDays.sorted() == [1, 7] ? Color.blue : Color.gray.opacity(0.15))
                        .foregroundColor(repeatDays.sorted() == [1, 7] ? .white : .black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    HStack(spacing: 8) {
                        ForEach(days, id: \.0) { day, name in
                            Button(action: {
                                if repeatDays.contains(day) {
                                    repeatDays.remove(day)
                                } else {
                                    repeatDays.insert(day)
                                }
                            }) {
                                Text(name)
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 38, height: 38)
                                    .background(repeatDays.contains(day) ? Color.blue : Color.gray.opacity(0.15))
                                    .foregroundColor(repeatDays.contains(day) ? .white : .black)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Tùy chọn làm sạch")) {
                    Picker("Chế độ dọn", selection: $selectedMode) {
                        Text("Tự động toàn nhà").tag("auto")
                        Text("Theo khu vực").tag("area")
                    }
                    
                    Picker("Lực hút", selection: $selectedFan) {
                        Text("Yên tĩnh").tag("quiet")
                        Text("Tiêu chuẩn").tag("standard")
                        Text("Mạnh").tag("max")
                        Text("Siêu mạnh").tag("max+")
                    }
                    
                    Picker("Lượng nước", selection: $selectedWater) {
                        ForEach(1...4, id: \.self) { level in
                            Text("Mức \(level)").tag(level)
                        }
                    }
                }
                
                Section(header: Text("Nhãn tên gợi nhớ")) {
                    TextField("Tên lịch hẹn", text: $labelText)
                }
                
                if let existing = existingSchedule {
                    Section {
                        Button(role: .destructive, action: {
                            viewModel.deleteSchedule(id: existing.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Xóa lịch hẹn giờ này")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(existingSchedule == nil ? "Thêm Lịch Mới" : "Chỉnh Sửa Lịch", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Hủy") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Lưu") {
                    let cal = Calendar.current
                    let hour = cal.component(.hour, from: selectedDate)
                    let min = cal.component(.minute, from: selectedDate)
                    let item = CleaningScheduleItem(
                        id: existingSchedule?.id ?? UUID().uuidString,
                        hour: hour,
                        minute: min,
                        repeatDays: Array(repeatDays).sorted(),
                        isEnabled: existingSchedule?.isEnabled ?? true,
                        cleanMode: selectedMode,
                        fanSpeed: selectedFan,
                        waterAmount: selectedWater,
                        label: labelText.isEmpty ? "Hẹn giờ dọn dẹp" : labelText
                    )
                    viewModel.addOrUpdateSchedule(item)
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 16, weight: .bold))
            )
        }
    }
}
