import { ScrollEffectType, HdsNavDestination, HdsNavDestinationTitleMode, PrefixCustomBuilder} from '@hms.hds.hdsBaseComponent';
import { LengthMetrics, promptAction, SymbolGlyphModifier, curves } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { MarkdownFile, FileDataSource } from '../class/MarkdownFile';
import { MarkdownViewerPage } from '../component/MarkdownViewerPage';
import { common } from '@kit.AbilityKit';
import { hdsEffect, HdsListItem, hdsMaterial } from '@kit.UIDesignKit';
import { EmptyView } from '../component/EmptyComponent';
import { MdDbService } from '../service/MdDbService';
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';
import { FloatWindowMainPage } from '../component/FloatBall';
import { systemShare, harmonyShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const TITLE_BAR_HEIGHT_FREE: number = 56 + 56 + 8;

@Component
export struct MdView {
  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Consume('pathStack') pathStack: NavPathStack;
  scroller: Scroller = new Scroller();
  @State blankHeight: number = TITLE_BAR_HEIGHT_FREE;
  @State isHideBackButton: boolean = false;
  @State titleMode: HdsNavDestinationTitleMode = HdsNavDestinationTitleMode.MINI;
  @StorageProp('safeTop') safeTop: number = 0;
  @StorageProp('safeBottom') safeBottom: number = 0;
  @Consume('dataSource') dataSource: FileDataSource;
  @Consume('dataVersion') dataVersion: number;
  @State searchKeyword: string = '';
  @State isSearchExpanded: boolean = false;
  @State geometryId: string = '';
  @State filteredFiles: MarkdownFile[] = [];
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private shareController: systemShare.ShareController | null = null;
  private shareTargetFile: MarkdownFile | null = null;
  @State isGridView: boolean = false;
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '全部' }, { text: '收藏' }] as ItemRestriction<SegmentButtonTextItem>,
    selectedFontColor: $r('sys.color.brand'),
    selectedBackgroundColor: $r('sys.color.comp_background_primary_contrary'),
    textPadding: {
      top: 6,
      right: 5,
      bottom: 6,
      left: 5
    }
  });
  @State tabSelectedIndexes: number[] = [0];
  @State starredFiles: MarkdownFile[] = [];
  @State allFiles: MarkdownFile[] = [];
  @State controller: hdsEffect.ShaderEffectController = new hdsEffect.ShaderEffectController();
  private isFirstShow: boolean = true;

  private isStarTab(): boolean {
    return this.tabSelectedIndexes.length > 0 && this.tabSelectedIndexes[0] === 1;
  }

  private refreshStarredFiles(): void {
    this.starredFiles = this.allFiles.filter((f: MarkdownFile) => f.isStar);
  }

  private refreshData(): void {
    this.allFiles = Array.from(this.dataSource.getAll());
    this.refreshStarredFiles();
    this.applySearchFilter();
  }

  @Builder
  stackBuilder() {
    Row() {
      Flex({ justifyContent: FlexAlign.Center }) {
        SegmentButton({
          options: this.tabOptions,
          selectedIndexes: $tabSelectedIndexes,
        })
          .width(150)
      }
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
  }


  private openSearch(): void {
    this.geometryId = 'search';
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38),
      onFinish: () => { this.geometryId = ''; }
    }, () => {
      this.isSearchExpanded = true;
    });
  }

  private closeSearch(): void {
    if (!this.isSearchExpanded) return;
    this.geometryId = 'search';
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38),
      onFinish: () => { this.geometryId = ''; }
    }, () => {
      this.isSearchExpanded = false;
    });
  }

  @Builder
  BottomBuilder(): void {
    Column() {
        Search({
          placeholder: '搜索markdown文件',
          value: this.searchKeyword
        })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .focusOnTouch(false)
          .focusable(false)
          .enableKeyboardOnFocus(false)
          .onClick(() => { this.openSearch(); })
          .geometryTransition(this.geometryId, { follow: true })
          .transition(TransitionEffect.OPACITY.animation({
            duration: 200,
            curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1)
          }));
      }
    .padding({ left: 16, right: 16 });
  }

  @Builder
  SearchExpandedBuilder(): void {
    Column() {
      Row() {
        Column(){
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(20)
            .borderRadius('50%')
            .fontColor([$r('sys.color.font_primary')])
            .onClick(() => { this.closeSearch(); })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.opacity(0)
                .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200, delay: 150 }),
              TransitionEffect.opacity(0)
                .animation({ curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1), duration: 200 })
            ));
        }
        .justifyContent(FlexAlign.Center)
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius('50%')
        .margin({right: 8})

        Search({ placeholder: '搜索markdown文件', value: this.searchKeyword })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .layoutWeight(1)
          .searchButton('搜索')
          .onChange((value: string) => {
            this.searchKeyword = value;
            this.applySearchFilter();
          })
          .onSubmit((value: string) => {
            this.searchKeyword = value;
            this.applySearchFilter();
          })
          .geometryTransition(this.geometryId, { follow: true })
          
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .margin({ top: this.safeTop });

      if (this.searchKeyword && this.filteredFiles.length === 0) {
        Column() {
          Text('未找到匹配文件')
            .fontSize(16)
            .fontColor($r('sys.color.font_secondary'));
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else if (this.searchKeyword) {
        List({ space: 12 }) {
          ForEach(this.filteredFiles, (item: MarkdownFile) => {
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
              }
              .height(56)
              .width('100%')
              .padding($r('sys.float.padding_level6'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .onClick(() => {
                this.closeSearch();
                setTimeout(() => {
                  this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                }, 250);
              });
            }
          }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
        }
        .height(undefined)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 });
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.doc_plaintext'))
            .fontSize(48)
            .fontColor([$r('sys.color.font_tertiary')])
            .margin({ bottom: 12 });
          Text('输入关键词搜索文件')
            .fontSize(16)
            .fontColor($r('sys.color.font_secondary'));
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'));
  }

  aboutToAppear(): void {
    this.loadLocalFiles();
    this.registerHarmonyShareListeners();
  }

  aboutToDisappear(): void {
    this.unregisterHarmonyShareListeners();
    this.dismissShareController();
  }

  private buildShareData(item: MarkdownFile): systemShare.SharedData {
    const fileUriStr = fileUri.getUriFromPath(item.sandboxPath);
    return new systemShare.SharedData({
      utd: utd.UniformDataType.FILE,
      uri: fileUriStr,
      title: item.name,
      description: 'Markdown文档',
    });
  }

  private doSystemShare(item: MarkdownFile): void {
    try {
      const shareData = this.buildShareData(item);
      this.shareController = new systemShare.ShareController(shareData);
      this.shareController.on('shareCompleted', (result: systemShare.ShareOperationResult) => {
        console.info('[MdView] 分享完成, 渠道: ' + result.targetAbilityInfo.name);
      });
      this.shareController.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE,
      });
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MdView] 拉起分享面板失败: ' + err.code + ' ' + err.message);
    }
  }

  private knockShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    if (!this.shareTargetFile) {
      sharableTarget.clarifyNonShare({ message: '请先选择要分享的文件' });
      return;
    }
    try {
      const shareData = this.buildShareData(this.shareTargetFile);
      sharableTarget.share(shareData);
      console.info('[MdView] 碰一碰分享已触发');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MdView] 碰一碰分享失败: ' + err.code + ' ' + err.message);
      sharableTarget.reject(harmonyShare.SharableErrorCode.DOWNLOAD_ERROR);
    }
  }

  private gesturesShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    if (!this.shareTargetFile) {
      sharableTarget.clarifyNonShare({ message: '请先选择要分享的文件' });
      return;
    }
    try {
      const shareData = this.buildShareData(this.shareTargetFile);
      sharableTarget.share(shareData);
      console.info('[MdView] 隔空传送已触发');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MdView] 隔空传送失败: ' + err.code + ' ' + err.message);
      sharableTarget.reject(harmonyShare.SharableErrorCode.DOWNLOAD_ERROR);
    }
  }

  private registerHarmonyShareListeners(): void {
    try {
      harmonyShare.on('knockShare', this.knockShareCallback);
    } catch (e) {
      console.error('[MdView] 注册碰一碰监听失败: ' + JSON.stringify(e));
    }
    try {
      harmonyShare.on('gesturesShare', this.gesturesShareCallback);
    } catch (e) {
      console.error('[MdView] 注册隔空传送监听失败: ' + JSON.stringify(e));
    }
  }

  private unregisterHarmonyShareListeners(): void {
    try {
      harmonyShare.off('knockShare', this.knockShareCallback);
    } catch (e) {
      console.error('[MdView] 注销碰一碰监听失败: ' + JSON.stringify(e));
    }
    try {
      harmonyShare.off('gesturesShare', this.gesturesShareCallback);
    } catch (e) {
      console.error('[MdView] 注销隔空传送监听失败: ' + JSON.stringify(e));
    }
  }

  private dismissShareController(): void {
    if (this.shareController) {
      this.shareController.off('shareCompleted');
      this.shareController = null;
    }
  }

  async loadLocalFiles(): Promise<void> {
    const dbService = MdDbService.getInstance(this.context);
    await dbService.init();
    await dbService.refreshGroupCache();

    const targetDir = this.context.filesDir + "/md_docs";
    const fsFiles: MarkdownFile[] = [];

    try {
      if (fs.accessSync(targetDir)) {
        const fileNames = fs.listFileSync(targetDir);
        for (const fileName of fileNames) {
          const targetPath = `${targetDir}/${fileName}`;
          const stats = fs.statSync(targetPath);
          fsFiles.push(new MarkdownFile(fileName, '', targetPath, stats.size));
        }
      }
    } catch (err) {
      console.error('[MdView] 读取文件系统失败:', JSON.stringify(err));
    }

    await dbService.syncFromFileSystem(fsFiles);

    this.dataSource.clear();
    const dbFiles = await dbService.queryAll();
    for (const file of dbFiles) {
      this.dataSource.pushItem(file);
    }
    this.dataVersion++;
    this.refreshData();
  }

  private applySearchFilter(): void {
    if (!this.searchKeyword) {
      this.filteredFiles = [];
      return;
    }
    const keyword: string = this.searchKeyword.toLowerCase();
    const source: MarkdownFile[] = this.isStarTab()
      ? this.starredFiles
      : this.allFiles;
    this.filteredFiles = source.filter((f: MarkdownFile) => f.name.toLowerCase().includes(keyword));
  }

  async readPickerFile(): Promise<void> {
    try {
      let pickerOpt = new picker.DocumentSelectOptions();
      pickerOpt.maxSelectNumber = 50;
      pickerOpt.fileSuffixFilters = ['application/markdown', 'text/markdown', '.md'];

      const documentViewPicker = new picker.DocumentViewPicker();
      const uris = await documentViewPicker.select(pickerOpt);

      if (!uris || uris.length === 0) return;

      const targetDir = this.context.filesDir + "/md_docs";
      if (!fs.accessSync(targetDir)) fs.mkdirSync(targetDir);

      const dbService = MdDbService.getInstance(this.context);
      const newFiles: MarkdownFile[] = [];

      for (let sourceUri of uris) {
        try {
          let srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
          if (!srcFile || !srcFile.name) {
            fs.closeSync(srcFile);
            continue;
          }

          const targetPath = `${targetDir}/${srcFile.name}`;

          let destFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          fs.copyFileSync(srcFile.fd, destFile.fd);

          const stats = fs.statSync(targetPath);
          const mdFile = new MarkdownFile(srcFile.name, sourceUri, targetPath, stats.size);
          this.dataSource.pushItem(mdFile);
          newFiles.push(mdFile);

          fs.closeSync(srcFile);
          fs.closeSync(destFile);
        } catch (err) {
          console.error("单个文件处理失败:", JSON.stringify(err));
        }
      }

      await dbService.insertFiles(newFiles);
      this.dataVersion++;
      this.refreshData();

    } catch (err) {
      console.error("批量导入失败: " + JSON.stringify(err));
    }
  }

  @Builder
  PageMap(name: string, param: object): void {
    if (name === 'MarkdownViewer') {
      MarkdownViewerPage({ fileData: param as MarkdownFile });
    }
  }

  @Builder
  listCard(item: MarkdownFile): void {
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
          .fontSize(24)
          .fontColor(['#FFC83D']);
      }
    }
    .width('100%')
    .padding($r('sys.float.padding_level6'));
  }

  @Builder
  gridCard(item: MarkdownFile): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.doc_plaintext_fill'))
            .fontSize(24)
            .fontColor(item.isStar ? ['#FFC83D']: [$r('sys.color.white')]);
          Text(item.groupName ? item.groupName : '')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.white'))
            .backgroundColor($r('sys.color.confirm'))
            .borderRadius(8)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .visibility(item.groupName ? Visibility.Visible : Visibility.Hidden);
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        Row(){
          Text(item.name)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.white'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.LEFT)
            .lineHeight(24)
            //.margin({ top: 4 });
        }
        .width('100%')
      }
      .width('100%')
      .height(undefined)
      .padding({ left: 12, right: 12, top: 16, bottom: 12 })
      .alignItems(HorizontalAlign.Center)
    }
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .shaderEffect({
        effectType: hdsEffect.EffectType.UV_BACKGROUND_FLOW_LIGHT,
        animation: {
          duration: 10000,
          iterations: -1,
          autoPlay: true,
          curve: Curve.FastOutSlowIn,
          onFinish: ()=> {
            console.info('Succeeded in finishing');
          }
        },
        controller: this.controller
      })
      .buildEffect())
    .borderRadius(16)
    .width('100%')
  }

  private async toggleStar(item: MarkdownFile): Promise<void> {
    try {
      const dbService = MdDbService.getInstance(this.context);
      const isStar: boolean = await dbService.toggleStar(item.sandboxPath);
      this.dataSource.updateItemStar(item.sandboxPath, isStar);
      this.dataVersion++;
      this.refreshData();
      const msg: string = isStar ? '已收藏' : '已取消收藏';
      promptAction.openToast({ message: msg, duration: 1000 }).catch(() => {});
    } catch (e) {
      console.error('[MdView] 切换收藏失败:', JSON.stringify(e));
    }
  }

  @Builder
  itemSwipeBuilder(item: MarkdownFile): void {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.folder_fill'))
          .fontSize(16)
          .fontColor([Color.White]);
      }
      .backgroundColor('#36C972')
      .width(48)
      .height(48)
      .margin({ left: 8 })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.star_fill'))
          .fontSize(16)
          .fontColor([Color.White]);
      }
      .backgroundColor('#FFC83D')
      .width(48)
      .height(48)
      .margin({ left: 8 })
      .onClick(() => { this.toggleStar(item); });
    }
  }
  @Builder
  ContentBuilder(){
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.allFiles.length > 0) {
          Scroll() {
            Column() {
              Blank().height(this.blankHeight + this.safeTop);
              if (this.searchKeyword && this.filteredFiles.length === 0) {
                Column() {
                  Text('未找到匹配文件')
                    .fontSize(16)
                    .fontColor($r('sys.color.font_secondary'));
                }
                .width('100%')
                .height('60%')
                .justifyContent(FlexAlign.Center);
              } else if (this.searchKeyword) {
                if (this.isGridView) {
                  GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
                    ForEach(this.filteredFiles, (item: MarkdownFile) => {
                      GridCol() {
                        Column() {
                          this.gridCard(item);
                        }
                        .backgroundColor($r('sys.color.comp_background_primary'))
                        .borderRadius(16)
                        .onClick(() => {
                          this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                        });
                      }
                    }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 });
                } else {
                  List({ space: 12 }) {
                    ForEach(this.filteredFiles, (item: MarkdownFile) => {
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
                        }
                        .height(56)
                        .width('100%')
                        .padding($r('sys.float.padding_level6'))
                        .backgroundColor($r('sys.color.comp_background_primary'))
                        .borderRadius(16)
                        .onClick(() => {
                          this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                        });
                      }
                      .swipeAction({
                        end: {
                          builder: () => { this.itemSwipeBuilder(item); }
                        }
                      });
                    }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                  }
                  .height(undefined)
                  .padding({left:16, right:16})
                  .width('100%');
                }
              } else if (this.isStarTab()) {
                if (this.starredFiles.length > 0) {
                  if (this.isGridView) {
                    GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
                      ForEach(this.starredFiles, (item: MarkdownFile) => {
                        GridCol() {
                          Column() {
                            this.gridCard(item);
                          }
                          .backgroundColor($r('sys.color.comp_background_primary'))
                          .borderRadius(16)
                          .onClick(() => {
                            this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                          });
                        }
                      }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16 });
                  } else {
                    List({ space: 12 }) {
                      ForEach(this.starredFiles, (item: MarkdownFile) => {
                        HdsListItem({
                          hdsListItemCard: {
                            prefixItem: new PrefixCustomBuilder(() => {
                              this.listCard(item);
                            }),
                            cardHeight: 64,
                            onClick: () => {
                              this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                            },
                          },
                          swipeActionOptions: {
                            icons: [
                              {
                                icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_fill')).fontColor([Color.White]).fontSize(16),
                                backgroundColor: '#36C972',
                                onAction: async () => {
                                }
                              },
                              {
                                icon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([Color.White]).fontSize(16),
                                backgroundColor: '#3A7BFF',
                                onAction: () => {
                                  this.shareTargetFile = item;
                                  this.doSystemShare(item);
                                }
                              },
                              {
                                icon: new SymbolGlyphModifier($r('sys.symbol.star_fill')).fontColor([Color.White]).fontSize(16),
                                backgroundColor: '#FFC83D',
                                onAction: () => {
                                  this.toggleStar(item);
                                }
                              }
                            ],
                            deleteIconOptions: {
                              backgroundColor: '#FF5A5F',
                              iconColor: Color.White,
                              onAction: () => {
                                promptAction.openToast({ message: '删除成功', duration: 100 }).catch(() => {});
                                this.getUIContext()?.animateTo({ duration: 350 }, () => {
                                  const index = this.dataSource.getIndex(item);
                                  if (index >= 0) {
                                    try {
                                      fs.unlinkSync(item.sandboxPath);
                                      MdDbService.getInstance(this.context).deleteFile(item.sandboxPath);
                                      this.dataSource.removeItem(index);
                                      this.dataVersion++;
                                      this.refreshData();
                                    } catch (e) {
                                      console.error("删除文件失败:", JSON.stringify(e));
                                    }
                                  }
                                });
                              },
                            },
                            fullDeleteOptions: {
                              isFullDelete: true,
                              onFullDeleteAction: () => {
                                promptAction.openToast({ message: '触发自动删除', duration: 100 }).catch(() => {});
                                this.getUIContext()?.animateTo({ duration: 350 }, () => {
                                  const index = this.dataSource.getIndex(item);
                                  if (index >= 0) {
                                    try {
                                      fs.unlinkSync(item.sandboxPath);
                                      MdDbService.getInstance(this.context).deleteFile(item.sandboxPath);
                                      this.dataSource.removeItem(index);
                                      this.dataVersion++;
                                      this.refreshData();
                                    } catch (e) {
                                      console.error("删除文件失败:", JSON.stringify(e));
                                    }
                                  }
                                });
                              }
                            }
                          }
                        });
                      }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                    }
                    .height(undefined)
                    .width('100%');
                  }
                } else {
                  Column() {
                    SymbolGlyph($r('sys.symbol.star'))
                      .fontSize(48)
                      .fontColor([$r('sys.color.font_tertiary')])
                      .margin({ bottom: 12 });
                    Text('暂无收藏文件')
                      .fontSize(16)
                      .fontColor($r('sys.color.font_secondary'));
                  }
                  .width('100%')
                  .height('60%')
                  .justifyContent(FlexAlign.Center);
                }
              } else {
                if (this.isGridView) {
                  GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
                    ForEach(this.allFiles, (item: MarkdownFile) => {
                      GridCol() {
                        Column() {
                          this.gridCard(item);
                        }
                        .backgroundColor($r('sys.color.comp_background_primary'))
                        .borderRadius(16)
                        .onClick(() => {
                          this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                        });
                      }
                    }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 });
                } else {
                  List({ space: 12 }) {
                    ForEach(this.allFiles, (item: MarkdownFile) => {
                      HdsListItem({
                        hdsListItemCard: {
                          prefixItem: new PrefixCustomBuilder(() => {
                            this.listCard(item);
                          }),
                          cardHeight: 64,
                          onClick: () => {
                            this.pathStack.pushPath({ name: 'MarkdownViewer', param: item });
                          },
                        },
                        swipeActionOptions: {
                          icons: [
                            {
                              icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_fill')).fontColor([Color.White]).fontSize(16),
                              backgroundColor: '#36C972',
                              onAction: async () => {
                              }
                            },
                            {
                              icon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([Color.White]).fontSize(16),
                              backgroundColor: '#3A7BFF',
                              onAction: () => {
                                this.shareTargetFile = item;
                                this.doSystemShare(item);
                              }
                            },
                            {
                              icon: new SymbolGlyphModifier($r('sys.symbol.star_fill')).fontColor([Color.White]).fontSize(16),
                              backgroundColor: '#FFC83D',
                              onAction: () => {
                                this.toggleStar(item);
                              }
                            }
                          ],
                          deleteIconOptions: {
                            backgroundColor: '#FF5A5F',
                            iconColor: Color.White,
                            onAction: () => {
                              promptAction.openToast({ message: '删除成功', duration: 100 }).catch(() => {});
                              this.getUIContext()?.animateTo({ duration: 350 }, () => {
                                const index = this.dataSource.getIndex(item);
                                if (index >= 0) {
                                  try {
                                    fs.unlinkSync(item.sandboxPath);
                                    MdDbService.getInstance(this.context).deleteFile(item.sandboxPath);
                                    this.dataSource.removeItem(index);
                                    this.dataVersion++;
                                    this.refreshData();
                                  } catch (e) {
                                    console.error("删除文件失败:", JSON.stringify(e));
                                  }
                                }
                              });
                            },
                          },
                          fullDeleteOptions: {
                            isFullDelete: true,
                            onFullDeleteAction: () => {
                              promptAction.openToast({ message: '触发自动删除', duration: 100 }).catch(() => {});
                              this.getUIContext()?.animateTo({ duration: 350 }, () => {
                                const index = this.dataSource.getIndex(item);
                                if (index >= 0) {
                                  try {
                                    fs.unlinkSync(item.sandboxPath);
                                    MdDbService.getInstance(this.context).deleteFile(item.sandboxPath);
                                    this.dataSource.removeItem(index);
                                    this.dataVersion++;
                                    this.refreshData();
                                  } catch (e) {
                                    console.error("删除文件失败:", JSON.stringify(e));
                                  }
                                }
                              });
                            }
                          }
                        }
                      });
                    }, (item: MarkdownFile) => `${item.sandboxPath}_${item.isStar}_${item.groupName}`);
                  }
                  .height(undefined)
                  .width('100%');
                }
              }
              Blank().height(56 + this.safeBottom + 8)
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
          }
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%');
        } else {
          EmptyView();
        }
      }
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        scrollEffectStyle: {
          backgroundStyle: { maskExtraHeight: 56.0 }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: ''
        },
        stackBuilder: (): void => this.stackBuilder(),
        bottomBuilder: {
          builder: () => { this.BottomBuilder(); },
          showType: 0
        },
        menu: {
          value: [
            {
              content: {
                label: 'menu1',
                icon: $r('sys.symbol.plus'),
                isEnabled: true,
                action: () => {
                  console.log('click');
                  this.readPickerFile();
                }
              }
            }
          ]
        },
        subIcon: {
          content: {
            label: 'viewToggle',
            icon: this.isGridView ? $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'),
            action: () =>{
              this.isGridView = !this.isGridView;
            }
          }
        },
      }
    })
    .titleMode(this.titleMode)
    .hideBackButton(true)
    .hideTitleBar(false)
    .onShown(() => {
      if (this.isFirstShow) {
        this.isFirstShow = false;
        return;
      }
      this.loadLocalFiles();
    })
    .bindContentCover(this.isSearchExpanded, this.SearchExpandedBuilder(), {
      modalTransition: ModalTransition.NONE,
      onDisappear: () => { this.closeSearch(); }
    });
  }
  build(): void {
      this.ContentBuilder()
  }
}

@Builder
export function MdViewBuilder(): void {
  MdView();
}