import { ScrollEffectType, HdsNavDestination, HdsNavDestinationTitleMode, PrefixCustomBuilder} from '@hms.hds.hdsBaseComponent';
import { LengthMetrics, promptAction, SymbolGlyphModifier, curves } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { MarkdownFile, FileDataSource } from '../class/MarkdownFile';
import { MarkdownViewerPage } from '../component/MarkdownViewerPage';
import { common } from '@kit.AbilityKit';
import { HdsListItem, hdsMaterial, HdsSideBar } from '@kit.UIDesignKit';
import { EmptyView } from '../component/EmptyComponent';
import { MdDbService } from '../service/MdDbService';
import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';
import { SideComponent } from '../component/SideCompoent'
import { FloatWindowMainPage } from '../component/FloatBall';

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
  @State isShowSidebar: boolean = false;
  @State isAutoHide: boolean = false;
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
  @State floatContainerWidth: number = 0;
  @State floatContainerHeight: number = 0;
  private isStarTab(): boolean {
    return this.tabSelectedIndexes.length > 0 && this.tabSelectedIndexes[0] === 1;
  }

  private refreshStarredFiles(): void {
    const all: MarkdownFile[] = Array.from(this.dataSource.getAll());
    this.starredFiles = all.filter((f: MarkdownFile) => f.isStar);
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
                      .fontSize($r('sys.float.Caption_S'))
                      .fontColor($r('sys.color.brand'))
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
          }, (item: MarkdownFile) => item.sandboxPath);
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
    this.refreshStarredFiles();
  }

  private applySearchFilter(): void {
    if (!this.searchKeyword) {
      this.filteredFiles = [];
      return;
    }
    const keyword: string = this.searchKeyword.toLowerCase();
    const source: MarkdownFile[] = this.isStarTab()
      ? this.starredFiles
      : Array.from(this.dataSource.getAll());
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
            .fontSize($r('sys.float.Caption_S'))
            .fontColor($r('sys.color.brand'))
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

  private async toggleStar(item: MarkdownFile): Promise<void> {
    try {
      const dbService = MdDbService.getInstance(this.context);
      const isStar: boolean = await dbService.toggleStar(item.sandboxPath);
      this.dataSource.updateItemStar(item.sandboxPath, isStar);
      this.dataVersion++;
      this.refreshStarredFiles();
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
  SideBarPanelBuilder() {
    SideComponent()
  }
  @Builder
  ContentBuilder(){
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.dataSource.totalCount() > 0) {
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
                              .fontSize($r('sys.float.Caption_S'))
                              .fontColor($r('sys.color.brand'))
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
                  }, (item: MarkdownFile) => item.sandboxPath);
                }
                .height(undefined)
                .padding({left:16, right:16})
                .width('100%')
              } else if (this.isStarTab()) {
                if (this.starredFiles.length > 0) {
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
                            /*
                            {
                              icon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_fill')).fontColor([Color.White]).fontSize(16),
                              backgroundColor: '#36C972',
                              onAction: async () => {
                              }
                            },
                            {
                              icon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([Color.White]).fontSize(16),
                              backgroundColor: '#3A7BFF',
                              onAction: () => {}
                            },
                            */
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
                                    this.refreshStarredFiles();
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
                                    this.refreshStarredFiles();
                                  } catch (e) {
                                    console.error("删除文件失败:", JSON.stringify(e));
                                  }
                                }
                              });
                            }
                          }
                        }
                      });
                    }, (item: MarkdownFile) => item.sandboxPath);
                  }
                  .height(undefined)
                  .width('100%')
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
                List({ space: 12 }) {
                  LazyForEach(this.dataSource, (item: MarkdownFile) => {
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
                            onAction: () => {}
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
                                } catch (e) {
                                  console.error("删除文件失败:", JSON.stringify(e));
                                }
                              }
                            });
                          }
                        }
                      }
                    });
                  }, (item: MarkdownFile) => item.sandboxPath);
                }
                .height(undefined)
                .width('100%')
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
      FloatWindowMainPage({ containerWidth: this.floatContainerWidth, containerHeight: this.floatContainerHeight })
      }
      .onAreaChange((oldValue: Area, newValue: Area) => {
        if (oldValue.width !== newValue.width) {
          this.floatContainerWidth = newValue.width as number;
        }
        if (oldValue.height !== newValue.height) {
          this.floatContainerHeight = newValue.height as number;
        }
      })
    }
    .backgroundColor($r('sys.color.background_secondary'))
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
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
            label: 'headIcon',
            icon: this.isShowSidebar ? $r('sys.symbol.open_sidebar') : $r('sys.symbol.close_sidebar'),
            action: () =>{
              this.isShowSidebar = !this.isShowSidebar;
            }
          }
        },
      }
    })
    .titleMode(this.titleMode)
    .hideBackButton(true)
    .hideTitleBar(false)
    .bindContentCover(this.isSearchExpanded, this.SearchExpandedBuilder(), {
      modalTransition: ModalTransition.NONE,
      onDisappear: () => { this.closeSearch(); }
    });
  }
  @BuilderParam sideBarBuilder: () => void = this.SideBarPanelBuilder
  @Builder
  HDSSideBarBuilder() {
    HdsSideBar({
      sideBarPanelBuilder: (): void => {
        this.sideBarBuilder()
      },
      contentPanelBuilder: (): void => {
        this.ContentBuilder()
      },
      autoHide: this.isAutoHide,
      contentAreaMask: true,
      sideBarContainerType: SideBarContainerType.Overlay,
      isShowSideBar: this.isShowSidebar,
      $isShowSideBar: (isShowSidebar: boolean) => {
        this.isShowSidebar = !isShowSidebar
      },
    })
  }

  build(): void {
      this.HDSSideBarBuilder()
  }
}

@Builder
export function MdViewBuilder(): void {
  MdView();
}