import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';

@Entry
@Component
struct Demo {
  // 1. 必须是@State + 数组
  @State selectedIndex: number[] = [0];

  // 2. 提前建好的options，不要放在build里
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '统计与分析' }, { text: '排行榜' }],
    textPadding: 7,
    fontWeight: FontWeight.Normal,
    selectedBackgroundColor: $r('sys.color.interactive_select')
  })
  build() {
    Column() {
      SegmentButton({
        options: this.tabOptions,
        selectedIndexes: this.selectedIndex
      })
      Text(`当前选中索引：${this.selectedIndex[0]}`)
        .margin(20)
    }
    .width('100%')
    .height('100%')
    .padding(24)
  }
}