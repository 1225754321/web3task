import { rmSync, existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve } from "path";

const persistent = resolve(__dirname, ".cfg/.cfgCache")
const temporary = resolve(__dirname, ".cfg/.cfgCacheTemp")

mkdirSync(persistent, { recursive: true });
mkdirSync(temporary, { recursive: true });

export function initTempIdDir(tempId: string) {
    const tempPath = resolve(temporary, tempId + ".json")
    mkdirSync(tempPath, { recursive: true })
}

export function DestroyedTempIdDir(tempId: string) {
    const tempPath = resolve(temporary, tempId + ".json")
    if (existsSync(tempPath)) {
        rmSync(tempPath, { recursive: true })
    }
}

export async function readCfg(cfgName: string, tempId?: string): Promise<any> {
    const storagePath = resolve(persistent, cfgName + ".json");
    if (!existsSync(storagePath)) {
        return {}
    }
    const storageData = readFileSync(storagePath, "utf-8");
    return JSON.parse(storageData)
}
export async function writeCfg(cfgName: string, data: any, notCovered?: boolean, tempId?: string) {
    const storagePath = resolve(persistent, cfgName + ".json");
    if (existsSync(storagePath) && notCovered) {
        const old = await readCfg(cfgName, tempId);
        data = { ...old, ...data }
    }
    writeFileSync(
        storagePath,
        JSON.stringify(data, null, 2),
    );
}

export const sleep = (ms: number): Promise<void> => new Promise(resolve => setTimeout(resolve, ms));