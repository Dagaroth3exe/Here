import { inflateRawSync } from 'node:zlib';

/**
 * The files inside a zip, by name. Only what .xlsx needs: stored or deflated
 * entries, located through the central directory at the end of the file.
 */
function unzip(file: Uint8Array): Record<string, Buffer> {
  const buf = Buffer.from(file.buffer, file.byteOffset, file.byteLength);
  // End-of-central-directory record: signature 0x06054b50, within the last 64 KB.
  let eocd = buf.length - 22;
  while (eocd >= Math.max(0, buf.length - 65_557) && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  if (eocd < 0 || buf.readUInt32LE(eocd) !== 0x06054b50) throw new Error('Not a zip file');
  const count = buf.readUInt16LE(eocd + 10);
  let entry = buf.readUInt32LE(eocd + 16);
  const files: Record<string, Buffer> = {};
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(entry) !== 0x02014b50) throw new Error('Corrupt zip directory');
    const method = buf.readUInt16LE(entry + 10);
    const size = buf.readUInt32LE(entry + 20);
    const nameLength = buf.readUInt16LE(entry + 28);
    const extraLength = buf.readUInt16LE(entry + 30);
    const commentLength = buf.readUInt16LE(entry + 32);
    const local = buf.readUInt32LE(entry + 42);
    const name = buf.toString('utf8', entry + 46, entry + 46 + nameLength);
    // The local header has its own name/extra lengths before the data.
    const start = local + 30 + buf.readUInt16LE(local + 26) + buf.readUInt16LE(local + 28);
    const data = buf.subarray(start, start + size);
    if (method === 0) files[name] = data;
    else if (method === 8) files[name] = inflateRawSync(data);
    entry += 46 + nameLength + extraLength + commentLength;
  }
  return files;
}

/**
 * The first worksheet of an .xlsx file as rows of cell text. Just enough of
 * the format for NCRB's tables — an .xlsx is a zip of XML parts: cell values
 * live in the sheet, text cells point into a shared-strings list.
 */
export function readFirstSheet(file: Uint8Array): string[][] {
  const parts = unzip(file);
  const text = (name: string) => parts[name]?.toString('utf8') ?? '';
  const decode = (s: string) =>
    s
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&amp;/g, '&');

  const shared = [...text('xl/sharedStrings.xml').matchAll(/<si>([\s\S]*?)<\/si>/g)].map((m) =>
    decode([...m[1].matchAll(/<t[^>]*>([\s\S]*?)<\/t>/g)].map((t) => t[1]).join('')),
  );

  const sheetName = Object.keys(parts)
    .filter((n) => /^xl\/worksheets\/sheet\d+\.xml$/.test(n))
    .sort()[0];
  if (!sheetName) throw new Error('No worksheet in file');

  const rows: string[][] = [];
  for (const row of text(sheetName).matchAll(/<row[^>]*>([\s\S]*?)<\/row>/g)) {
    const cells: string[] = [];
    for (const cell of row[1].matchAll(/<c r="([A-Z]+)\d+"([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const [, ref, attrs, body = ''] = cell;
      const col = [...ref].reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0) - 1;
      const value = /<v>([\s\S]*?)<\/v>/.exec(body)?.[1] ?? /<t[^>]*>([\s\S]*?)<\/t>/.exec(body)?.[1] ?? '';
      cells[col] = /t="s"/.test(attrs) ? (shared[Number(value)] ?? '') : decode(value);
    }
    rows.push(Array.from(cells, (c) => c ?? ''));
  }
  return rows;
}
