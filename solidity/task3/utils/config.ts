import { rmSync, existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve } from "path";

const persistent = resolve(__dirname, "./.cfgCache")
const temporary = resolve(__dirname, "./.cfgCacheTemp")

mkdirSync(persistent, { recursive: true });
mkdirSync(temporary, { recursive: true });

export function initTempIdDir(tempId: string) {
    const tempPath = resolve(temporary, tempId)
    mkdirSync(tempPath, { recursive: true })
}

export function DestroyedTempIdDir(tempId: string) {
    const tempPath = resolve(temporary, tempId)
    if (existsSync(tempPath)) {
        rmSync(tempPath, { recursive: true })
    }
}

export async function readCfg(cfgName: string, tempId?: string): Promise<any> {
    const storagePath = resolve(__dirname, "./.cfgCache", cfgName + ".json");
    const storageData = readFileSync(storagePath, "utf-8");
    return JSON.parse(storageData)
}
export async function writeCfg(cfgName: string, data: any, tempId?: string) {
    const storagePath = resolve(__dirname, "./.cfgCache", cfgName + ".json");
    writeFileSync(
        storagePath,
        JSON.stringify(data, null, 2),
    );
}