import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { MarkdownFile } from '../class/MarkdownFile';
import { FileDataSource } from '../class/MarkdownFile';

export class FileService {
  private static instance: FileService | null = null;
  private context: common.UIAbilityContext;
  private readonly BASE_DIR: string = '/md_docs';

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.initDir();
  }

  static getInstance(context: common.UIAbilityContext): FileService {
    if (!FileService.instance) {
      FileService.instance = new FileService(context);
    }
    return FileService.instance;
  }

  private initDir(): void {
    const targetDir: string = this.context.filesDir + this.BASE_DIR;
    if (!fs.accessSync(targetDir)) {
      fs.mkdirSync(targetDir);
    }
  }

  loadLocalFiles(): MarkdownFile[] {
    const targetDir: string = this.context.filesDir + this.BASE_DIR;
    const fileList: MarkdownFile[] = [];

    try {
      if (fs.accessSync(targetDir)) {
        const fileNames: string[] = fs.listFileSync(targetDir);
        for (let fileName of fileNames) {
          const path: string = `${targetDir}/${fileName}`;
          const stats = fs.statSync(path);
          fileList.push(new MarkdownFile(fileName, '', path, stats.size));
        }
      }
    } catch (err) {
      console.error('[FileService] 加载文件失败:', JSON.stringify(err));
    }
    return fileList;
  }

  deleteFile(item: MarkdownFile): boolean {
    try {
      fs.unlinkSync(item.sandboxPath);
      return true;
    } catch (e) {
      console.error('[FileService] 删除失败:', JSON.stringify(e));
      return false;
    }
  }

  getTargetDir(): string {
    return this.context.filesDir + this.BASE_DIR;
  }
}