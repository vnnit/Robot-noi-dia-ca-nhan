import SwiftUI

public struct ScheduleView: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showAddScheduleSheet: Bool = false
    @State private var editingSchedule: CleaningScheduleItem? = nil
    
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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Button(action: { showAddScheduleSheet = true }) {
                            Text("Thêm lịch hẹn giờ")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.state.schedules) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.timeString)
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    Text(item.label)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(white: 0.2))
                                    Text(item.repeatDaysText)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { _ in viewModel.toggleSchedule(id: item.id) }
                                ))
                                .labelsHidden()
                            }
                            .padding(.vertical, 6)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteSchedule(id: item.id)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
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
                trailing: Button(action: { showAddScheduleSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
            )
            .sheet(isPresented: $showAddScheduleSheet) {
                AddScheduleSheet(viewModel: viewModel)
            }
        }
    }
}

struct AddScheduleSheet: View {
    @ObservedObject var viewModel: RobotControlViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDate = Date()
    @State private var labelText = "Hẹn giờ dọn dẹp"
    @State private var repeatDays: Set<Int> = [2, 3, 4, 5, 6] // T2-T6
    @State private var selectedMode = "auto"
    @State private var selectedFan = "standard"
    
    let days = [
        (2, "T2"), (3, "T3"), (4, "T4"), (5, "T5"), (6, "T6"), (7, "T7"), (1, "CN")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thời gian")) {
                    DatePicker("Giờ bắt đầu", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                
                Section(header: Text("Lặp lại")) {
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
                
                Section(header: Text("Nhãn tên")) {
                    TextField("Tên lịch hẹn", text: $labelText)
                }
            }
            .navigationBarTitle("Thêm Lịch Mới", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Hủy") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Lưu") {
                    let cal = Calendar.current
                    let hour = cal.component(.hour, from: selectedDate)
                    let min = cal.component(.minute, from: selectedDate)
                    let item = CleaningScheduleItem(
                        hour: hour,
                        minute: min,
                        repeatDays: Array(repeatDays).sorted(),
                        isEnabled: true,
                        cleanMode: selectedMode,
                        fanSpeed: selectedFan,
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
