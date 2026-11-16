/** Shared data contract for the Creative Moments browser preview.
 * The original preview localStorage key is retained so existing browser data loads unchanged.
 * No remote storage or third-party analytics are used.
 */
export const STORAGE_KEY = 'creative-moments-browser-preview-v1';
export const RECOVERY_KEY = 'creative-moments-browser-preview-pre-restore-v1';
export const BACKUP_FORMAT = 'creative-moments-web-backup';
export const BACKUP_VERSION = 1;
export const isMonthKey = key => /^\d{4}-(0[1-9]|1[0-2])$/.test(key);
export const DEFAULT_STATE = () => ({ tasks: {}, notes: {}, days: {}, drawings: {}, joy: {}, carry: {}, focus: {}, coverName: 'My Creative Moments', coverImage: '' });
export const monthKey = (year, month) => `${year}-${String(month).padStart(2, '0')}`;
export const validDate = key => {
  if (typeof key !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(key)) return false;
  const [year, month, day] = key.split('-').map(Number);
  const d = new Date(year, month - 1, day);
  return d.getFullYear() === year && d.getMonth() === month - 1 && d.getDate() === day;
};
export function normalizeState(input) {
  const out = DEFAULT_STATE();
  if (!input || typeof input !== 'object' || Array.isArray(input)) return out;
  for (const key of ['tasks', 'notes', 'days', 'drawings', 'joy', 'carry', 'focus']) {
    if (input[key] && typeof input[key] === 'object' && !Array.isArray(input[key])) out[key] = input[key];
  }
  if (typeof input.coverName === 'string') out.coverName = input.coverName.slice(0, 100);
  if (typeof input.coverImage === 'string' && (/^data:image\/(jpeg|png|webp);base64,[a-zA-Z0-9+/=]+$/.test(input.coverImage) || input.coverImage === '')) out.coverImage = input.coverImage;
  // Old preview entries had no id or dueDate; do not mutate those records here.
  return out;
}
export function readState(storage) {
  const raw = storage.getItem(STORAGE_KEY);
  if (raw == null) return { state: DEFAULT_STATE(), error: null };
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw Error('Not an object');
    const checked = validateBackup({format: BACKUP_FORMAT, version: BACKUP_VERSION, data: parsed});
    if (!checked.ok) throw Error(checked.error);
    return { state: checked.data, error: null };
  } catch {
    return { state: DEFAULT_STATE(), error: 'Saved browser data could not be read. Existing data was NOT overwritten. Export the raw browser data before changing anything.' };
  }
}
export function persistState(storage, next) {
  try {
    storage.setItem(STORAGE_KEY, JSON.stringify(next));
    return { ok: true, error: null };
  } catch (error) {
    return { ok: false, error: `Your latest change was not saved (${error?.name || 'storage error'}). Free browser space or export your work before continuing.` };
  }
}
export function makeBackup(state, date = new Date()) {
  return { format: BACKUP_FORMAT, version: BACKUP_VERSION, exportedAt: date.toISOString(), data: structuredClone(state) };
}
const isObject = o => o && typeof o === 'object' && !Array.isArray(o);
export function validateBackup(raw) {
  if (!isObject(raw) || raw.format !== BACKUP_FORMAT || raw.version !== BACKUP_VERSION || !isObject(raw.data)) return { ok: false, error: 'Not a compatible Creative Moments backup.' };
  const input = raw.data;
  for (const k of ['tasks', 'notes', 'days', 'drawings', 'joy', 'carry', 'focus']) {
    if (input[k] !== undefined && !isObject(input[k])) return { ok: false, error: `Invalid ${k} section.` };
  }
  if (input.coverImage !== undefined && (typeof input.coverImage !== 'string' || (input.coverImage && !/^data:image\/(jpeg|png|webp);base64,[a-zA-Z0-9+/=]+$/.test(input.coverImage)))) return { ok: false, error: 'Invalid cover photo.' };
  if (input.coverName !== undefined && typeof input.coverName !== 'string') return { ok: false, error: 'Invalid cover title.' };
  for (const [month, tasks] of Object.entries(input.tasks || {})) {
    if (!isMonthKey(month) || !Array.isArray(tasks) || tasks.length > 10000) return { ok: false, error: 'Invalid checklist.' };
    for (const item of tasks) if (!isObject(item) || typeof item.title !== 'string' || item.title.length > 2000 || (item.done !== undefined && typeof item.done !== 'boolean') || (item.dueDate && !validDate(item.dueDate))) return { ok: false, error: 'Invalid checklist item.' };
  }
  for (const section of ['notes', 'days', 'joy', 'carry', 'focus']) {
    for (const [key, val] of Object.entries(input[section] || {})) {
      if (typeof val !== 'string' || val.length > 1000000) return { ok: false, error: 'Invalid text entry.' };
      if (section === 'days' ? !/^\d{4}-(0[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])$/.test(key) : !isMonthKey(key)) return { ok: false, error: 'Invalid entry date.' };
    }
  }
  for (const [key, drawing] of Object.entries(input.drawings || {})) {
    if (!/^\d{4}-(0[1-9]|1[0-2])-(season|sketch|patterns|free)$/.test(key) || !isObject(drawing) || !Array.isArray(drawing.strokes) || drawing.strokes.length > 20000) return { ok: false, error: 'Invalid drawing.' };
    for (const stroke of drawing.strokes) {
      if (!isObject(stroke) || !Array.isArray(stroke.points) || stroke.points.length > 50000 || typeof stroke.color !== 'string' || !Number.isFinite(stroke.width) || stroke.width <= 0 || stroke.width > 300) return { ok: false, error: 'Invalid drawing stroke.' };
      for (const point of stroke.points) if (!Array.isArray(point) || point.length !== 2 || !point.every(v => Number.isFinite(v) && v >= -10000 && v <= 10000)) return { ok: false, error: 'Invalid drawing coordinates.' };
    }
  }
  return { ok: true, data: normalizeState(input), error: null };
}
export function overdueTasks(state, todayKey) {
  const result = [];
  for (const [month, tasks] of Object.entries(state.tasks || {})) {
    if (!Array.isArray(tasks)) continue;
    for (const task of tasks) if (!task.done && validDate(task.dueDate) && task.dueDate <= todayKey) result.push({ month, task });
  }
  return result.sort((a, b) => a.task.dueDate.localeCompare(b.task.dueDate));
}
export function moveUnfinished(state, targetMonth) {
  if (!isMonthKey(targetMonth)) throw new Error('Invalid target month.');
  const [year, month] = targetMonth.split('-').map(Number);
  const prev = month === 1 ? monthKey(year - 1, 12) : monthKey(year, month - 1);
  const outgoing = Array.isArray(state.tasks[prev]) ? state.tasks[prev] : [];
  const active = outgoing.filter(t => !t.done);
  if (!active.length) return { moved: 0, from: prev };
  const existing = Array.isArray(state.tasks[targetMonth]) ? state.tasks[targetMonth] : [];
  const ids = new Set(existing.map(t => t.id).filter(Boolean));
  const next = [...existing];
  let moved = 0;
  for (const [index, task] of active.entries()) {
    // Existing target copies are not duplicated. Legacy tasks without IDs gain one.
    const id = task.id || `${prev}-legacy-${outgoing.indexOf(task)}-${index}`;
    if (ids.has(id)) continue;
    ids.add(id);
    next.push({ ...task, id, dueDate: task.dueDate && task.dueDate < `${targetMonth}-01` ? `${targetMonth}-01` : (task.dueDate || '') });
    moved++;
  }
  state.tasks[targetMonth] = next;
  state.tasks[prev] = outgoing.filter(t => t.done);
  return { moved, from: prev };
}
