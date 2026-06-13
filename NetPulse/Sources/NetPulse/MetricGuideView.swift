import SwiftUI

struct MetricGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("指标与路由说明")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            Group {
                GuideSection(
                    title: "Shadowrocket TUN",
                    detail: "表示 Shadowrocket 的虚拟网络接口已经接管连接。它说明流量进入了 TUN，但不能单独证明最终使用“直连”还是“代理”；最终路线由 Shadowrocket 规则决定。"
                )
                GuideSection(
                    title: "Fake-IP 与 198.18 地址",
                    detail: "198.18.0.0–198.19.255.255 是保留的测试地址段。Shadowrocket 用它把域名映射到虚拟地址。它不是你的本地真实 IP、不是公网出口 IP，也不是网站服务器 IP；仅显示该地址不会造成隐私泄露。"
                )
                GuideSection(
                    title: "成功与丢失",
                    detail: "成功表示完成了真实 HTTP 访问；丢失包含连接失败、TLS 失败和超时。只要出现丢失，即标记为“不稳定”。"
                )
                GuideSection(
                    title: "中位、P95、最慢",
                    detail: "中位数代表典型体验；P95 用于观察尾部延迟；最慢是单次最大耗时。每项仅采样 3 次时，P95 基本等同于最慢的成功采样。"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("速度判断")
                    .font(.headline)
                ThresholdRow(color: .green, title: "优秀", detail: "< 300ms")
                ThresholdRow(color: .teal, title: "良好", detail: "300–800ms")
                ThresholdRow(color: .orange, title: "偏慢", detail: "800ms–1.5s")
                ThresholdRow(color: .red, title: "很慢", detail: "≥ 1.5s")
                Text("任何失败或超时优先判定为“不稳定”；全部失败则为“不可用”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 620, height: 610)
    }
}

private struct GuideSection: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThresholdRow: View {
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .frame(width: 52, alignment: .leading)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.callout.monospacedDigit())
    }
}
