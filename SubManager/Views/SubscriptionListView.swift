import SwiftUI

struct SubscriptionListView: View {
    @EnvironmentObject var viewModel: SubscriptionViewModel

    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("正在更新订阅...")
                        Spacer()
                    }
                }

                ForEach(viewModel.subscriptions) { subscription in
                    NavigationLink(destination: NodeListView(subscription: subscription)) {
                        SubscriptionRow(subscription: subscription)
                    }
                }
                .onDelete(perform: deleteSubscription)
            }
            .navigationTitle("订阅管理")
            .navigationBarItems(
                leading: Button(action: {
                    viewModel.updateAllSubscriptions()
                }) {
                    Image(systemName: "arrow.clockwise")
                },
                trailing: Button(action: {
                    viewModel.showAddSubscription = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .overlay(
                VStack {
                    if viewModel.subscriptions.isEmpty && !viewModel.isLoading {
                        Text("还没有订阅")
                            .foregroundColor(.gray)
                        Text("点击右上角 + 添加订阅")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            )
        }
    }

    private func deleteSubscription(at offsets: IndexSet) {
        offsets.forEach { index in
            viewModel.removeSubscription(viewModel.subscriptions[index])
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    @EnvironmentObject var viewModel: SubscriptionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subscription.name)
                    .font(.headline)
                Spacer()
                Text("\(subscription.nodeCount) 节点")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Text(subscription.url)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            HStack {
                if let updateTime = subscription.updateTime {
                    Text("更新于 \(timeAgo(updateTime))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text("未更新")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Spacer()

                Button(action: {
                    viewModel.updateSubscription(subscription)
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}
