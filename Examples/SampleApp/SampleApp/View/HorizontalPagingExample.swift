import SwiftUI
import ListKit

struct HorizontalPagingExample: View {
    private let behaviors: [(title: String, description: String, behavior: LKSectionOrthogonalScrollingBehavior)] = [
        ("None", "가로 스크롤을 사용하지 않고 기본 세로 섹션처럼 배치합니다.", .none),
        ("Continuous", "멈춤 위치를 보정하지 않고 손가락 속도에 따라 자연스럽게 이어서 스크롤합니다.", .continuous),
        ("Leading Boundary", "연속 스크롤하되 멈출 때 보이는 그룹의 왼쪽 경계에 맞춥니다.", .continuousGroupLeadingBoundary),
        ("Paging", "컬렉션뷰 화면 폭을 기준으로 한 페이지씩 넘깁니다.", .paging),
        ("Group Paging", "레이아웃 그룹 하나를 기준으로 한 칸씩 넘깁니다.", .groupPaging),
        ("Group Paging Centered", "레이아웃 그룹 하나를 기준으로 넘기고, 멈출 때 그룹을 가운데에 맞춥니다.", .groupPagingCentered),
    ]

    var body: some View {
        LKList {
            for configuration in behaviors {
                LKSection(id: configuration.title) {
                    for message in ListKitExampleData.messages {
                        LKRow("\(configuration.title)-\(message.id)", id: \.self) {
                            ExampleMessageRow(message: message)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.title)
                            .font(.headline)
                        Text(configuration.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .sectionLayout(.horizontal(width: 300))
                .scrollAxis(.horizontal)
                .orthogonalScrollingBehavior(configuration.behavior)
                .itemSpacing(12)
                .pinnedHeader()
            }
        }
    }
}

#Preview {
    HorizontalPagingExample()
}
