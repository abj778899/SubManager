import SwiftUI

struct AddSubscriptionView: View {
    @EnvironmentObject var viewModel: SubscriptionViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var url = ""
    @State private var isAdding = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("订阅信息")) {
                    TextField("订阅名称（如：一元机场）", text: $name)
                    TextField("订阅链接", text: $url)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("预设订阅")) {
                    Button(action: {
                        name = "一元机场"
                        url = "https://sub2.smallstrawberry.com/api/v1/client/subscribe?token=74ffb35155f2d0098ff814b82e3949fc"
                    }) {
                        HStack {
                            Text("一元机场")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Section {
                    Button(action: addSubscription) {
                        HStack {
                            Spacer()
                            if isAdding {
                                ProgressView()
                            } else {
                                Text("添加订阅")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(url.isEmpty || isAdding)
                }
            }
            .navigationTitle("添加订阅")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func addSubscription() {
        isAdding = true
        let subscriptionName = name.isEmpty ? "新订阅" : name
        viewModel.addSubscription(name: subscriptionName, url: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
