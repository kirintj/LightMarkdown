import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { promptAction } from '@kit.ArkUI';
import { MarkdownFile, FileDataSource, FileGroup } from '../class/MarkdownFile';
import { MdDbService } from '../service/MdDbService'
import { common } from '@kit.AbilityKit';
import { hdsMaterial } from '@kit.UIDesignKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { HdsMiniBarButton } from 'hds_button';

@Component
export struct MultiSelectPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('dataSource') dataSource: FileDataSource;
  @Consume('dataVersion') dataVersion: number;
  @StorageProp('safeTop') safeTop: number = 0;
  @StorageProp('safeBottom') safeBottom: number = 0;
  @State allFiles: MarkdownFile[] = [];
  @State selectedPaths: string[] = [];
  @State showGroupSheet: boolean = false;
  @State titleMode: HdsNavDestinationTitleMode = HdsNavDestinationTitleMode.MINI;
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private shareController: systemShare.ShareController | null = null;
  @State groups: FileGroup[] = [];
  @State groupTargetFile: MarkdownFile | null = null;
  @State newGroupName: string = '';

  async aboutToAppear(): Promise<void> {
    await this.loadData();
  }

  aboutToDisappear(): void {
    this.dismissShareController();
  }

  async loadData(): Promise<void> {
    try {
      const dbService = MdDbService.getInstance(this.context);
      await dbService.init();
      await dbService.refreshGroupCache();
      this.allFiles = await dbService.queryAll();
      this.groups = await dbService.queryAllGroups();
    } catch (e) {
      console.error('[MultiSelectPage] 加载数据失败:', JSON.stringify(e));
    }
  }

  private isSelected(path: string): boolean {
    return this.selectedPaths.indexOf(path) >= 0;
  }

  private toggleSelect(path: string): void {
    if (this.isSelected(path)) {
      this.selectedPaths = this.selectedPaths.filter((p: string) => p !== path);
    } else {
      const updated: string[] = Array.from(this.selectedPaths);
      updated.push(path);
      this.selectedPaths = updated;
    }
  }

  private selectAll(): void {
    const paths: string[] = [];
    for (const file of this.allFiles) {
      paths.push(file.sandboxPath);
    }
    this.selectedPaths = paths;
  }

  private deselectAll(): void {
    this.selectedPaths = [];
  }

  private getSelectedFiles(): MarkdownFile[] {
    const result: MarkdownFile[] = [];
    for (const file of this.allFiles) {
      if (this.isSelected(file.sandboxPath)) {
        result.push(file);
      }
    }
    return result;
  }

  private async doGroup(): Promise<void> {
    const dbService = MdDbService.getInstance(this.context);
    this.groups = await dbService.queryAllGroups();
    this.showGroupSheet = true;
  }

  private async assignToGroup(groupId: number, groupName: string): Promise<void> {
    const selected = this.getSelectedFiles();
    try {
      const dbService = MdDbService.getInstance(this.context);
      for (const file of selected) {
        await dbService.setFileGroup(file.sandboxPath, groupId);
        this.dataSource.updateItemGroup(file.sandboxPath, groupId, groupName);
      }
      this.showGroupSheet = false;
      this.dataVersion++;
      await this.loadData();
      this.selectedPaths = [];
      promptAction.openToast({ message: `已将${selected.length}个文件加入分组「${groupName}」`, duration: 1000 }).catch(() => {});
    } catch (e) {
      console.error('[MultiSelectPage] 分组失败:', JSON.stringify(e));
    }
  }

  private async doStar(): Promise<void> {
    const selected = this.getSelectedFiles();
    if (selected.length === 0) return;
    try {
      const dbService = MdDbService.getInstance(this.context);
      let starredCount: number = 0;
      for (const file of selected) {
        if (!file.isStar) {
          await dbService.setStar(file.sandboxPath, true);
          this.dataSource.updateItemStar(file.sandboxPath, true);
          starredCount++;
        }
      }
      this.dataVersion++;
      await this.loadData();
      this.selectedPaths = [];
      promptAction.openToast({ message: `已收藏${starredCount}个文件`, duration: 1000 }).catch(() => {});
    } catch (e) {
      console.error('[MultiSelectPage] 收藏失败:', JSON.stringify(e));
    }
  }

  private doShare(): void {
    const selected = this.getSelectedFiles();
    if (selected.length === 0) return;
    try {
      const item = selected[0];
      const fileUriStr = fileUri.getUriFromPath(item.sandboxPath);
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.FILE,
        uri: fileUriStr,
        title: item.name,
        description: 'Markdown文档',
      });
      this.shareController = new systemShare.ShareController(shareData);
      this.shareController.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE,
      });
      this.selectedPaths = [];
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MultiSelectPage] 分享失败: ' + err.code + ' ' + err.message);
      promptAction.openToast({ message: '分享失败', duration: 1000 }).catch(() => {});
    }
  }

  private dismissShareController(): void {
    if (this.shareController) {
      this.shareController.off('shareCompleted');
      this.shareController = null;
    }
  }

  private doDelete(): void {
    const selected = this.getSelectedFiles();
    if (selected.length === 0) return;
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除选中的${selected.length}个文件吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        action: () => { this.deleteSelectedFiles(); }
      }
    });
  }

  private async deleteSelectedFiles(): Promise<void> {
    const selected = this.getSelectedFiles();
    let successCount: number = 0;
    for (const file of selected) {
      try {
        fs.unlinkSync(file.sandboxPath);
        await MdDbService.getInstance(this.context).deleteFile(file.sandboxPath);
        const index = this.dataSource.getIndex(file);
        if (index >= 0) {
          this.dataSource.removeItem(index);
        }
        successCount++;
      } catch (e) {
        console.error('[MultiSelectPage] 删除文件失败:', JSON.stringify(e));
      }
    }
    this.dataVersion++;
    this.selectedPaths = [];
    await this.loadData();
    promptAction.openToast({ message: `已删除${successCount}个文件`, duration: 1000 }).catch(() => {});
  }

  @Builder
  fileListBuilder(): void {
    if (this.allFiles.length === 0) {
      Column() {
        SymbolGlyph($r('sys.symbol.doc_plaintext'))
          .fontSize(48)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ bottom: 12 });
        Text('暂无文件')
          .fontSize(16)
          .fontColor($r('sys.color.font_secondary'));
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center);
    } else {
      List({ space: 12 }) {
        ForEach(this.allFiles, (item: MarkdownFile) => {
          ListItem() {
            Row() {
              SymbolGlyph($r('sys.symbol.doc_plaintext_fill'))
                .fontSize($r('sys.float.Title_M'))
                .fontColor([$r('sys.color.brand')]);
              Column() {
                Text(item.name)
                  .fontSize($r('sys.float.Subtitle_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
                if (item.groupName) {
                  Text(item.groupName)
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .fontSize($r('sys.float.Caption_S'))
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.white'))
                    .backgroundColor($r('sys.color.confirm'))
                    .borderRadius(8)
                    .margin({ top: 2 });
                }
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: $r('sys.float.padding_level6') })
              .layoutWeight(1);
              Blank();
              if (item.isStar) {
                SymbolGlyph($r('sys.symbol.star_fill'))
                  .fontSize(16)
                  .fontColor(['#FFC83D']);
              }
              Checkbox()
                .select(this.isSelected(item.sandboxPath))
                .onChange((_checked: boolean) => {
                  this.toggleSelect(item.sandboxPath);
                })
                .margin({ left: 12 });
            }
            .height(56)
            .width('100%')
            .padding($r('sys.float.padding_level6'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
            .onClick(() => {
              this.toggleSelect(item.sandboxPath);
            });
          }
        }, (item: MarkdownFile) => `${item.sandboxPath}_${this.isSelected(item.sandboxPath)}`);
      }
      .width('100%')
      .padding({ left: 16, right: 16 });
    }
  }

  private async createAndAssignGroup(): Promise<void> {
    const selected = this.getSelectedFiles();
    if (selected.length === 0 || !this.newGroupName.trim()) return;
    const groupName: string = this.newGroupName.trim();
    try {
      const dbService = MdDbService.getInstance(this.context);
      const groupId: number = await dbService.createGroup(groupName);
      for (const file of selected) {
        await dbService.setFileGroup(file.sandboxPath, groupId);
        this.dataSource.updateItemGroup(file.sandboxPath, groupId, groupName);
      }
      this.dataVersion++;
      await this.loadData();
      this.newGroupName = '';
      this.showGroupSheet = false;
      promptAction.openToast({ message: `已创建分组「${groupName}」并将${selected.length}个文件加入`, duration: 1000 }).catch(() => {});
    } catch (e) {
      console.error('[MultiSelectPage] 创建分组失败:', JSON.stringify(e));
    }
  }
  private async removeFromGroup(): Promise<void> {
    if (!this.groupTargetFile) return;
    try {
      const dbService = MdDbService.getInstance(this.context);
      await dbService.removeFileGroup(this.groupTargetFile.sandboxPath);
      this.dataSource.updateItemGroup(this.groupTargetFile.sandboxPath, -1, '');
      this.dataVersion++;
      this.showGroupSheet = false;
      this.groupTargetFile = null;
      promptAction.openToast({ message: '已移出分组', duration: 1000 }).catch(() => {});
    } catch (e) {
      console.error('[MdView] 移出分组失败:', JSON.stringify(e));
    }
  }

  @Builder
  groupSheetBuilder() {
    HdsNavDestination(){
      Column() {
        Row() {
          TextInput({ placeholder: '创建新分组', text: this.newGroupName })
            .layoutWeight(1)
            .onChange((value: string) => { this.newGroupName = value; })
            .onSubmit(() => { this.createAndAssignGroup(); });
          Button('创建')
            .type(ButtonType.Capsule)
            .backgroundColor($r('sys.color.brand'))
            .fontColor(Color.White)
            .height(40)
            .margin({ left: 8 })
            .enabled(this.newGroupName.trim().length > 0)
            .onClick(() => { this.createAndAssignGroup(); });
        }
        .width('100%')
        .margin({ bottom : 12 });
        if (this.groups.length > 0) {
          List({ space: 8 }) {
            ForEach(this.groups, (group: FileGroup) => {
              ListItem() {
                Row() {
                  SymbolGlyph($r('sys.symbol.arrow_right_folder_fill'))
                    .fontSize(24)
                    .fontColor([$r('sys.color.brand')]);
                  Text(group.name)
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                    .margin({ left: 12 })
                    .layoutWeight(1);
                  if (this.groupTargetFile && this.groupTargetFile.groupId === group.id) {
                    SymbolGlyph($r('sys.symbol.checkmark_circle'))
                      .fontSize(24)
                      .fontColor([$r('sys.color.brand')]);
                  }
                }
                .backgroundColor(this.groupTargetFile && this.groupTargetFile.groupId === group.id? $r('sys.color.comp_emphasize_secondary'):$r('sys.color.comp_background_primary'))
                .height(56)
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .borderRadius(16)
                .onClick(() => { this.assignToGroup(group.id, group.name); });
              }
            }, (group: FileGroup) => group.id.toString());
          }
        }
        if (this.groupTargetFile && this.groupTargetFile.groupId !== -1) {
          Row() {
            SymbolGlyph($r('sys.symbol.clean_fill'))
              .fontSize(24)
              .fontColor([$r('sys.color.warning')]);
            Text('移出当前分组')
              .fontColor($r('sys.color.warning'))
              .margin({ left: 12 })
              .layoutWeight(1);
          }
          .backgroundColor($r('sys.color.comp_background_primary'))
          .height(56)
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .borderRadius(16)
          .margin({ top: 12 })
          .onClick(() => { this.removeFromGroup(); });
        }
      }
      .padding({right: 16, left: 16})
      .width('100%')
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .hideBackButton(true)
    .titleMode(HdsNavDestinationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
      },
      enableComponentSafeArea: true,
      content: {
        title: {
          mainTitle: '分组',
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.xmark'),
              action: () => {
                this.showGroupSheet = false;
              },
            }
          }]
        },
      },
    })
  }

  @Builder
  actionButton(icon: Resource, label: string, color: string | Resource ,action: () => void): void {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([color])
      Text(label)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .onClick(() => {
      if (this.selectedPaths.length === 0) {
        promptAction.openToast({ message: '请先选择文件', duration: 1000 }).catch(() => {});
        return;
      }
      action();
    })
  }

  build(): void {
    HdsNavDestination() {
      Stack({alignContent: Alignment.Bottom}){
        Scroll(){
          Column() {
            Blank().height(this.safeTop + 56);
            this.fileListBuilder();
            Blank().height(this.safeBottom+ 56)
          }
          .width('100%')
        }
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        HdsMiniBarButton({
          barWidth: 240,
          barHeight: 56,
          barBottomMargin: 16,
          maskColor: Color.Transparent
        }
        ){
          Row() {
            this.actionButton($r('sys.symbol.share'), '分享', '#3A7BFF', (): void => { this.doShare(); });
            this.actionButton($r('sys.symbol.folder_fill'), '分组', '#36C972', (): void => { this.doGroup(); });
            this.actionButton($r('sys.symbol.star_fill'), '收藏', '#FFC83D', (): void => { this.doStar(); });
            this.actionButton($r('sys.symbol.trash_fill'), '删除', '#FF5A5F',(): void => { this.doDelete(); });
          }
          .justifyContent(FlexAlign.SpaceAround)
          .width('100%')
          //.padding({ left: 16, right: 16, top: 12, bottom: this.safeBottom + 12 })
        }
      }
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: {
          mainTitle: `多选 (${this.selectedPaths.length})`,
        },
        menu: {
          value: [{
            content: {
              label: 'selectAll',
              icon: $r('sys.symbol.checkmark_circle'),
              action: () => {
                if (this.selectedPaths.length === this.allFiles.length) {
                  this.deselectAll();
                } else {
                  this.selectAll();
                }
              }
            }
          }]
        },
      }
    })
    .titleMode(this.titleMode)
    .bindSheet(this.showGroupSheet, this.groupSheetBuilder(), {
      height: SheetSize.MEDIUM,
      showClose: true,
      backgroundColor: $r('sys.color.comp_background_primary'),
      onDisappear: () => {
        this.showGroupSheet = false;
      }
    });
  }
}

@Builder
export function MultiSelectPageBuilder(): void {
  MultiSelectPage();
}
