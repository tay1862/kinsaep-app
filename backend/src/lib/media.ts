import { mkdir, writeFile } from 'fs/promises';
import path from 'path';

const uploadsRoot = path.resolve(process.cwd(), 'uploads');

export async function saveThumbnailData(
  storeId: string,
  fileName: string,
  input: string,
): Promise<string> {
  const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, '_');
  const storeDir = path.join(uploadsRoot, storeId);
  await mkdir(storeDir, { recursive: true });

  const filePath = path.join(storeDir, safeName);
  const base64 = input.includes(',') ? input.split(',')[1] : input;
  await writeFile(filePath, Buffer.from(base64, 'base64'));

  return `/media/${storeId}/${safeName}`;
}

export function getUploadsRoot(): string {
  return uploadsRoot;
}
