import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { open, save, confirm } from '@tauri-apps/plugin-dialog';
import { openUrl } from '@tauri-apps/plugin-opener';
import {
  createIcons, LayoutDashboard, History, BookOpen, ChartNoAxesCombined, Cpu,
  Settings, Mic, Square, Copy, Trash2, Pin, Download, Check, ArrowUpRight,
  Keyboard, ShieldCheck, Search, Clock3, AlignLeft, AudioLines, Sparkles,
  LockKeyhole, SlidersHorizontal, Info, Palette, ChevronDown,
  ChevronRight, FileText, Timer, Activity, Plus, RotateCcw,
  MoreHorizontal, Mouse, CircleCheck,
} from 'lucide';
import './style.css';

interface Entry {
  id: string; kind: string; sourcePhrase: string; targetPhrase: string | null;
  notes: string | null; isEnabled: boolean; createdAt: string; updatedAt: string;
}
interface Transcript {
  id: string; timestamp: string; originalTranscript: string; correctedText: string;
  duration: number; insertionResult: string;
  correctionAudit: { heard: string; written: string }[]; isPinned: boolean;
}
interface Preferences {
  model: string; keepHistory: boolean; retention: string; recordingMode: string;
  shortcut: string; appearance: string; onboardingDone: boolean; autoInsert: boolean; showReadyIndicator: boolean;
}
interface Model { id: string; name: string; bytes: number }
interface Snapshot {
  data: { preferences: Preferences; history: Transcript[]; dictionary: Entry[]; recovery: string | null };
  phase: string; models: Model[]; installed: string[]; ready: boolean; settingUp: boolean;
  notice: string | null; shortcutError: string | null; capability: string;
  platform: string; version: string;
}

const root = document.querySelector<HTMLDivElement>('#app')!;
const overlay = new URLSearchParams(location.search).has('overlay');
const privacyURL = 'https://dictate-macos.vercel.app/privacy';
const sections = ['dashboard', 'history', 'dictionary', 'statistics', 'models', 'settings'] as const;
type Section = typeof sections[number];
type SettingsTab = 'general' | 'audio' | 'permissions';

const names: Record<Section, string> = {
  dashboard: 'Dashboard', history: 'History', dictionary: 'Dictionary',
  statistics: 'Statistics', models: 'AI models', settings: 'Settings',
};
const glyphs: Record<Section, string> = {
  dashboard: 'layout-dashboard', history: 'history', dictionary: 'book-open',
  statistics: 'chart-no-axes-combined', models: 'cpu', settings: 'settings',
};
const allIcons = {
  LayoutDashboard, History, BookOpen, ChartNoAxesCombined, Cpu, Settings, Mic,
  Square, Copy, Trash2, Pin, Download, Check, ArrowUpRight, Keyboard, ShieldCheck,
  Search, Clock3, AlignLeft, AudioLines, Sparkles, LockKeyhole, SlidersHorizontal,
  Info, Palette, ChevronDown, ChevronRight, FileText, Timer, Activity, Plus,
  RotateCcw, MoreHorizontal, Mouse, CircleCheck,
};

let state: Snapshot;
let section: Section = 'dashboard';
let settingsTab: SettingsTab = 'general';
let selectedDay = 'today';
let search = '';
let localError = '';
let progress = '';
let busy = false;
let editing: string | null = null;
let expandedHistory: string | null = null;
let statsRange: 'week' | 'month' | 'year' = 'week';
let capturing = false;
let modifierCandidate = '';
let capturedMouse: number | null = null;
let showSetupOptions = false;
let optimisticPreferences: Preferences | null = null;
let pendingPreferences: Preferences | null = null;
let savingPreferences = false;

type DraftField = { name: string; value: string; checked: boolean };
const formDrafts = new Map<string, DraftField[]>();
const resetDrafts = new Set<string>();

const esc = (value: unknown) => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[char]!));
const icon = (name: string) => `<i data-lucide="${name}" aria-hidden="true"></i>`;
const brandMark = () => '<span class="brand-mark"><img src="/dictate-mark.svg" alt=""></span>';
const button = (action: string, label: string, cls = '', attrs = '') =>
  `<button type="button" data-action="${action}" class="${cls}" ${attrs}>${label}</button>`;
const wordCount = (text: string) => text.trim().split(/\s+/).filter(Boolean).length;
const secondsLabel = (seconds: number) => {
  const rounded = Math.round(seconds);
  return `${String(Math.floor(rounded / 60)).padStart(2, '0')}:${String(rounded % 60).padStart(2, '0')}`;
};
const timeLabel = (value: string) => new Date(value).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
const dayKey = (date: Date) => `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
const sameDay = (value: string, date: Date) => dayKey(new Date(value)) === dayKey(date);
const modelSize = (bytes: number) => bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`;

function preserveUI() {
  root.querySelectorAll<HTMLFormElement>('form[id]').forEach(form => {
    if (!resetDrafts.has(form.id)) {
      formDrafts.set(form.id, Array.from(form.querySelectorAll<HTMLInputElement>('input[name],select[name]'))
        .map(element => ({ name: element.name, value: element.value, checked: element.checked })));
    }
  });
  const active = document.activeElement as HTMLInputElement;
  const key = active?.id ? `#${CSS.escape(active.id)}`
    : active?.name ? `[name="${CSS.escape(active.name)}"]${active.type === 'radio' ? `[value="${CSS.escape(active.value)}"]` : ''}`
      : active?.dataset.section ? `[data-section="${active.dataset.section}"]`
        : active?.dataset.action ? `[data-action="${active.dataset.action}"]${active.dataset.id ? `[data-id="${active.dataset.id}"]` : ''}` : null;
  const start = active?.selectionStart;
  const end = active?.selectionEnd;
  return () => {
    root.querySelectorAll<HTMLFormElement>('form[id]').forEach(form => {
      if (resetDrafts.has(form.id)) {
        formDrafts.delete(form.id);
        resetDrafts.delete(form.id);
        return;
      }
      for (const field of formDrafts.get(form.id) ?? []) {
        const element = Array.from(form.querySelectorAll<HTMLInputElement>(`[name="${CSS.escape(field.name)}"]`))
          .find(candidate => candidate.type !== 'radio' || candidate.value === field.value);
        if (!element) continue;
        if (element.type !== 'radio') element.value = field.value;
        if (element.type === 'checkbox' || element.type === 'radio') element.checked = field.checked;
      }
    });
    const target = key ? root.querySelector<HTMLInputElement>(key) : null;
    target?.focus({ preventScroll: true });
    if (target && start != null && end != null && ['text', 'search', 'url', 'tel', 'password'].includes(target.type)) target.setSelectionRange(start, end);
  };
}

let refreshing: Promise<void> | null = null;
async function refresh() {
  if (refreshing) return refreshing;
  refreshing = (async () => {
    try {
      const snapshot = await invoke<Snapshot>('get_state');
      if (savingPreferences && optimisticPreferences) snapshot.data.preferences = optimisticPreferences;
      state = snapshot; render();
    }
    catch (error) {
      localError = String(error);
      if (!state) root.innerHTML = `<main class="startup"><h1>Dictate could not connect</h1><p>${esc(error)}</p>${button('reload', 'Try again')}</main>`;
    }
  })();
  try { await refreshing; } finally { refreshing = null; }
}

async function call(command: string, args: Record<string, unknown> = {}, resetForm?: string) {
  if (busy) return;
  busy = true; localError = '';
  try { await invoke(command, args); if (resetForm) resetDrafts.add(resetForm); }
  catch (error) { localError = String(error); }
  finally { busy = false; await refresh(); }
}

async function savePreference(changes: Partial<Preferences>) {
  optimisticPreferences = { ...(optimisticPreferences ?? state.data.preferences), ...changes };
  pendingPreferences = optimisticPreferences;
  state.data.preferences = optimisticPreferences;
  localError = '';
  render();
  if (savingPreferences) return;
  savingPreferences = true;
  let saveFailed = false;
  while (pendingPreferences) {
    const preferences = pendingPreferences;
    pendingPreferences = null;
    try { await invoke('save_preferences', { preferences }); }
    catch (error) {
      localError = String(error);
      pendingPreferences = null;
      saveFailed = true;
      break;
    }
  }
  savingPreferences = false;
  optimisticPreferences = null;
  resetDrafts.add('settings-form');
  await refresh();
  // A state-change event can have an older refresh in flight while a save fails.
  // Read once more so the controls always return to the last durable settings.
  if (saveFailed) await refresh();
}

function status() {
  if (state.phase === 'listening') return 'Listening';
  if (state.phase === 'preparing') return 'Starting microphone';
  if (state.phase === 'finalizing') return 'Transcribing locally';
  if (state.phase === 'delivering') return 'Returning your words';
  if (state.settingUp) return 'Preparing model';
  return state.ready ? 'Dictate ready' : 'Set up a model';
}

function shortcutLabel(value: string) {
  return value.split('+').map(key => ({
    ControlRight: 'Right Ctrl', ControlLeft: 'Left Ctrl', AltRight: 'Right Alt', AltLeft: 'Left Alt',
    ShiftRight: 'Right Shift', ShiftLeft: 'Left Shift', MetaLeft: 'Left Windows', MetaRight: 'Right Windows',
    MouseMiddle: 'Middle mouse', MouseBack: 'Mouse back', MouseForward: 'Mouse forward',
    CommandOrControl: 'Ctrl', Space: 'Space',
  }[key] ?? key.replace(/^Key|^Digit/, '').replace('Arrow', ''))).join(' + ');
}

function recordingButton() {
  const listening = state.phase === 'listening';
  const pending = ['preparing', 'finalizing', 'delivering'].includes(state.phase);
  const mark = listening ? '<span class="stop-mark" aria-hidden="true"></span>' : icon('mic');
  return button(listening ? 'finish' : 'record', mark + (listening ? 'Finish recording' : 'Start recording'), listening ? 'record-button recording' : 'primary record-button', (!state.ready || pending || state.data.recovery ? 'disabled' : ''));
}

function eyebrowHeader(eyebrow: string, title: string, subtitle: string, actions = '') {
  return `<header class="page-header"><div><p class="eyebrow">${eyebrow}</p><h1 tabindex="-1">${title}</h1><p class="subtitle">${subtitle}</p></div>${actions ? `<div class="header-actions">${actions}</div>` : ''}</header>`;
}

function cardHeader(iconName: string, title: string, detail: string) {
  return `<header class="card-header"><span class="icon-tile">${icon(iconName)}</span><div><h2>${title}</h2><p>${detail}</p></div></header>`;
}

function segments(name: string, items: [string, string][], selected: string) {
  return `<div class="segments" role="radiogroup" aria-label="${esc(name)}">${items.map(([value, label]) => `<label><input type="radio" name="${name}" value="${value}" ${value === selected ? 'checked' : ''}><span>${label}</span></label>`).join('')}</div>`;
}

function feedback() {
  if (!localError && !state.notice && !state.data.recovery) return '';
  return `<div class="feedback" aria-live="polite">${localError ? `<p class="notice error">${esc(localError)}</p>` : ''}${state.notice ? `<p class="notice">${esc(state.notice)}</p>` : ''}${state.data.recovery ? `<section class="recovery">${cardHeader('rotate-ccw', 'Your words are safe', 'Insertion did not finish, so Dictate kept the transcript here.')}<p class="transcript">${esc(state.data.recovery)}</p><div class="actions">${button('copy-recovery', icon('copy') + 'Copy', 'primary')}${button('retry-delivery', 'Retry insertion in 3 seconds')}${button('discard-recovery', 'Discard', 'danger')}</div></section>` : ''}</div>`;
}

function sidebar() {
  return `<aside class="sidebar"><button class="brand" data-section="dashboard" aria-label="Open Dashboard">${brandMark()}<strong>Dictate</strong></button><p class="nav-label">Workspace</p><nav aria-label="Main navigation">${sections.map(item => `<button data-section="${item}" ${state.data.preferences.onboardingDone && section === item ? 'aria-current="page"' : ''}>${icon(glyphs[item])}<span>${names[item]}</span></button>`).join('')}</nav><div class="sidebar-status"><span class="dot ${state.phase === 'listening' ? 'recording' : state.ready ? 'ready' : ''}"></span><div><strong>${status()}</strong><small>LOCAL · PRIVATE</small></div></div></aside>`;
}

function dashboard() {
  const history = state.data.history;
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(); date.setHours(0, 0, 0, 0); date.setDate(date.getDate() - (6 - index));
    return { date, words: history.filter(item => sameDay(item.timestamp, date)).reduce((sum, item) => sum + wordCount(item.correctedText), 0) };
  });
  const weekWords = days.reduce((sum, day) => sum + day.words, 0);
  const max = Math.max(1, ...days.map(day => day.words));
  const chartPoints = days.map((day, index) => ({
    ...day,
    x: ((index + .5) / days.length) * 100,
    y: 82 - (day.words / max) * 58,
  }));
  const points = chartPoints.map(point => `${point.x},${point.y}`).join(' ');
  const model = state.models.find(item => item.id === state.data.preferences.model);
  const modelAction = `<button class="model-status-button" data-section="models"><span class="dot ${state.ready ? 'ready' : ''}"></span><span><strong>${esc(model?.name ?? 'Choose a local model')}</strong><small>${state.ready ? 'On-device · ready' : 'Setup needed'}</small></span>${icon('chevron-right')}</button>`;
  const recent = history.slice(0, 3);
  return `<div class="content-shell dashboard-page">${eyebrowHeader('Your voice, in motion', 'Good to hear you.', 'A calm place to see what Dictate is doing for you.', modelAction + recordingButton())}<section class="overview-card"><div class="overview-copy"><h2>Week activity</h2><p>Words captured each day</p><strong>${weekWords.toLocaleString()}</strong><span>words dictated</span></div><div class="line-chart" aria-label="Words dictated over the last seven days"><div class="line-plot"><svg viewBox="0 0 100 92" preserveAspectRatio="none" aria-hidden="true"><polyline points="${points}"/></svg>${chartPoints.map(point => `<span class="chart-point" tabindex="0" aria-label="${esc(point.date.toLocaleDateString(undefined, { weekday: 'long' }))}: ${point.words} words" style="left:${point.x}%;top:${(point.y / 92) * 100}%"><span class="chart-tooltip">${point.words} ${point.words === 1 ? 'word' : 'words'}</span></span>`).join('')}</div><div class="chart-labels">${days.map(day => `<span>${day.date.toLocaleDateString(undefined, { weekday: 'narrow' })}</span>`).join('')}</div></div></section><div class="dashboard-grid"><section class="surface-card quick-card"><h2>Quick actions</h2><p>Move from thought to text.</p>${[['history', 'history', 'Open history', 'Review recent dictation'], ['dictionary', 'book-open', 'Manage dictionary', 'Shape the words Dictate knows'], ['models', 'cpu', 'Choose a model', 'Tune speed and accuracy']].map(([target, glyph, title, detail]) => `<button data-section="${target}" class="quick-row">${icon(glyph)}<span><strong>${title}</strong><small>${detail}</small></span>${icon('arrow-up-right')}</button>`).join('')}</section><section class="surface-card recent-card"><header><div><h2>Recent transcriptions</h2><p>The last few things you said</p></div>${recent.length ? '<button class="link-button" data-section="history">View all</button>' : ''}</header>${recent.length ? recent.map(item => `<button class="recent-row" data-section="history"><span class="dot ready"></span><span><strong>${esc(item.correctedText)}</strong><small>${timeLabel(item.timestamp)}</small></span><time>${secondsLabel(item.duration)}</time></button>`).join('') : '<div class="quiet-empty">Your completed dictations will appear here.</div>'}</section></div></div>`;
}

function historyDayTabs() {
  const dates = Array.from({ length: 7 }, (_, index) => { const date = new Date(); date.setDate(date.getDate() - index); return date; });
  return `<div class="day-index" role="tablist" aria-label="History day">${dates.map((date, index) => { const value = index === 0 ? 'today' : dayKey(date); return `<button data-action="history-day" data-id="${value}" role="tab" aria-selected="${selectedDay === value}"><span>${date.toLocaleDateString(undefined, { weekday: 'short' }).toUpperCase()}</span><strong>${date.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })}</strong></button>`; }).join('')}<button data-action="history-day" data-id="all" role="tab" aria-selected="${selectedDay === 'all'}"><span>ALL</span>${icon('more-horizontal')}</button></div>`;
}

function historyRow(item: Transcript) {
  const date = new Date(item.timestamp);
  const expanded = expandedHistory === item.id;
  const inserted = ['insertedViaPaste', 'insertedViaAccessibility'].includes(item.insertionResult);
  return `<article class="history-card ${expanded ? 'expanded' : ''}"><div class="date-block"><strong>${date.getDate()}</strong><span>${date.toLocaleDateString(undefined, { month: 'short' }).toUpperCase()}</span></div><div class="history-content"><p class="history-transcript">${esc(item.correctedText)}</p><div class="history-meta">${icon('clock-3')} ${timeLabel(item.timestamp)} ${icon('align-left')} ${wordCount(item.correctedText)} words ${icon('audio-lines')} ${secondsLabel(item.duration)} <span class="status-chip ${inserted ? 'success' : ''}"><span class="dot ${inserted ? 'ready' : ''}"></span>${inserted ? 'Inserted' : 'Ready to copy'}</span></div>${expanded ? `<div class="history-actions">${button('copy-history', icon('copy') + 'Copy', 'quiet', `data-id="${item.id}"`)}${button('pin-history', icon('pin') + (item.isPinned ? 'Unpin' : 'Pin'), 'quiet', `data-id="${item.id}"`)}${button('delete-history', icon('trash-2') + 'Delete', 'quiet danger', `data-id="${item.id}"`)}</div>${item.correctionAudit.length ? `<p class="audit">${item.correctionAudit.map(audit => `${esc(audit.heard)} → ${esc(audit.written)}`).join(' · ')}</p>` : ''}` : ''}</div><button class="expand-button" data-action="toggle-history" data-id="${item.id}" aria-label="${expanded ? 'Collapse' : 'Expand'} transcript" aria-expanded="${expanded}">${icon('chevron-down')}</button></article>`;
}

function historyView() {
  const query = search.trim().toLowerCase();
  const items = state.data.history.filter(item => {
    const matchesSearch = !query || item.correctedText.toLowerCase().includes(query);
    if (selectedDay === 'all') return matchesSearch;
    const date = new Date();
    if (selectedDay !== 'today') { const [year, month, day] = selectedDay.split('-').map(Number); date.setFullYear(year, month - 1, day); }
    return matchesSearch && sameDay(item.timestamp, date);
  });
  const dayLabel = selectedDay === 'today' ? 'Today' : selectedDay === 'all' ? 'All' : new Date(`${selectedDay}T12:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  return `<div class="history-page">${historyDayTabs()}<header class="history-toolbar"><div><h1 tabindex="-1">History</h1><span class="day-pill">${dayLabel}</span></div><label class="history-search">${icon('search')}<span class="sr-only">Search history</span><input id="search" type="search" value="${esc(search)}" placeholder="Search history"></label><span class="item-count">${items.length} items</span>${button('export-history', icon('more-horizontal'), 'icon-button', 'aria-label="More history actions"')}</header><main class="history-scroll">${items.length ? `<div class="history-section-title"><span></span><strong>${dayLabel.toUpperCase()}</strong><small>${items.length}</small><i></i></div>${items.map(historyRow).join('')}` : `<section class="empty-state">${icon('history')}<h2>${query ? 'No matching dictations' : 'Your words will live here'}</h2><p>${query ? 'Try a different word or clear the search.' : 'Record your first thought. It will be saved here when history is enabled.'}</p>${query ? button('clear-search', 'Clear search') : ''}</section>`}</main></div>`;
}

function dictionaryForm(entry?: Entry) {
  return `<form id="dictionary-form" class="surface-card dictionary-form"><header><div><h2>${entry ? 'Edit rule' : 'Add a rule'}</h2><p>Teach Dictate a name or the spelling you prefer.</p></div>${button('cancel-edit', 'Cancel', 'quiet')}</header><div class="form-grid"><label>Type<select name="kind"><option value="correction" ${entry?.kind === 'correction' ? 'selected' : ''}>Correction</option><option value="vocabulary" ${entry?.kind === 'vocabulary' ? 'selected' : ''}>Vocabulary</option></select></label><label>Heard phrase<input name="source" required maxlength="2048" value="${esc(entry?.sourcePhrase)}" placeholder="codecs"></label><label>Write instead<input name="target" maxlength="2048" value="${esc(entry?.targetPhrase)}" placeholder="codex"></label></div><button type="submit" class="primary">${entry ? 'Save changes' : 'Add rule'}</button></form>`;
}

function dictionaryView() {
  const entries = state.data.dictionary;
  const edit = editing && editing !== 'new' ? entries.find(entry => entry.id === editing) : undefined;
  const actions = `${button('import-dictionary', 'Import', 'quiet')}${button('export-dictionary', 'Export', 'quiet')}${button('add-entry', icon('plus') + 'Add rule', 'primary')}`;
  return `<div class="content-shell dictionary-page"><header class="plain-header"><div><h1 tabindex="-1">Dictionary</h1><p>Teach Dictate preferred words and spoken corrections.</p></div><div class="header-actions">${actions}</div></header><p class="collection-count">${entries.length} ${entries.length === 1 ? 'rule' : 'rules'}</p>${editing ? dictionaryForm(edit) : ''}<section class="dictionary-surface">${entries.length ? entries.map((entry, index) => `<article class="dictionary-row"><span class="rule-index" style="--rule:${['var(--coral)', 'var(--violet)', 'var(--moss)', 'var(--amber)'][index % 4]}"></span><div><strong>${esc(entry.sourcePhrase)}</strong>${entry.targetPhrase ? `${icon('arrow-up-right')}<strong class="target-word">${esc(entry.targetPhrase)}</strong>` : ''}<small>${entry.kind === 'correction' ? 'Corrections' : 'Vocabulary'} · ${new Date(entry.updatedAt).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })}</small></div><div class="row-actions">${button('toggle-entry', entry.isEnabled ? 'Enabled' : 'Disabled', 'quiet', `data-id="${entry.id}" aria-pressed="${entry.isEnabled}"`)}${button('edit-entry', 'Edit', 'quiet', `data-id="${entry.id}"`)}${button('delete-entry', icon('trash-2'), 'icon-button danger', `data-id="${entry.id}" aria-label="Delete ${esc(entry.sourcePhrase)}"`)}</div></article>`).join('') : `<div class="empty-state">${icon('book-open')}<h2>Make it sound like you</h2><p>Add a correction for names, products, and phrases Dictate should spell your way.</p>${button('add-entry', icon('plus') + 'Add rule', 'primary')}</div>`}</section></div>`;
}

function statisticsView() {
  const now = new Date();
  const cutoff = new Date(now);
  if (statsRange === 'week') cutoff.setDate(cutoff.getDate() - 6);
  else if (statsRange === 'month') cutoff.setDate(cutoff.getDate() - 27);
  else cutoff.setMonth(cutoff.getMonth() - 11, 1);
  cutoff.setHours(0, 0, 0, 0);
  const history = state.data.history.filter(item => new Date(item.timestamp) >= cutoff);
  const words = history.reduce((sum, item) => sum + wordCount(item.correctedText), 0);
  const seconds = history.reduce((sum, item) => sum + item.duration, 0);
  const average = history.length ? Math.round(words / history.length) : 0;
  const listening = `${Math.floor(seconds / 3600)}:${String(Math.floor((seconds % 3600) / 60)).padStart(2, '0')}`;
  const count = statsRange === 'week' ? 7 : statsRange === 'month' ? 4 : 12;
  const buckets = Array.from({ length: count }, (_, index) => {
    const start = new Date(now); const end = new Date(now);
    if (statsRange === 'week') { start.setDate(start.getDate() - (count - 1 - index)); end.setTime(start.getTime()); }
    else if (statsRange === 'month') { start.setDate(start.getDate() - ((count - index) * 7 - 1)); end.setDate(end.getDate() - ((count - 1 - index) * 7)); }
    else { start.setMonth(start.getMonth() - (count - 1 - index), 1); end.setMonth(start.getMonth() + 1, 0); }
    start.setHours(0, 0, 0, 0); end.setHours(23, 59, 59, 999);
    const value = history.filter(item => { const date = new Date(item.timestamp); return date >= start && date <= end; }).reduce((sum, item) => sum + wordCount(item.correctedText), 0);
    const label = statsRange === 'week' ? start.toLocaleDateString(undefined, { weekday: 'narrow' }) : statsRange === 'month' ? start.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : start.toLocaleDateString(undefined, { month: 'short' });
    return { label, value };
  });
  const max = Math.max(1, ...buckets.map(bucket => bucket.value));
  const period = statsRange === 'week' ? 'this week' : statsRange === 'month' ? 'last 4 weeks' : 'last 12 months';
  const metrics = [['align-left', 'Total words', words.toLocaleString(), period, 'violet'], ['file-text', 'Sessions', history.length.toLocaleString(), 'transcriptions', 'blue'], ['activity', 'Average', average.toLocaleString(), 'words per session', 'moss'], ['timer', 'Listening time', listening, 'captured locally', 'amber']];
  return `<div class="content-shell statistics-page">${eyebrowHeader('A little signal', 'Statistics.', 'See how your voice compounds into written work.', segments('statsRange', [['week', 'Week'], ['month', 'Month'], ['year', 'Year']], statsRange))}<div class="metric-grid">${metrics.map(([glyph, label, value, detail, color]) => `<article class="metric-card ${color}">${icon(glyph)}<span>${label}</span><strong>${value}</strong><small>${detail}</small></article>`).join('')}</div><section class="surface-card activity-card"><h2>Activity</h2><p>${period[0].toUpperCase() + period.slice(1)} of dictation</p><div class="bar-chart" style="--columns:${count}">${buckets.map((bucket, index) => `<div class="bar-column" tabindex="0" aria-label="${esc(bucket.label)}: ${bucket.value} words"><span class="bar-tooltip">${bucket.value} ${bucket.value === 1 ? 'word' : 'words'}</span><i style="height:${Math.max(4, (bucket.value / max) * 100)}%;--bar:${index === count - 1 ? 'var(--violet)' : 'var(--accent-blue)'}"></i><span>${bucket.label}</span></div>`).join('')}</div></section></div>`;
}

function modelAction(model: Model, prominent = false) {
  const active = state.ready && state.data.preferences.model === model.id;
  const installed = state.installed.includes(model.id);
  if (active) return `<span class="active-badge">${icon('circle-check')}ACTIVE</span>`;
  return button('select-model', installed ? 'Use model' : 'Download', prominent ? 'primary' : '', `data-id="${model.id}" ${state.settingUp ? 'disabled' : ''}`);
}

function modelRow(model: Model) {
  const active = state.ready && state.data.preferences.model === model.id;
  const installed = state.installed.includes(model.id);
  const parakeet = model.id === 'parakeet';
  return `<article class="catalog-row ${active ? 'active' : ''}"><span class="model-icon ${parakeet ? 'moss' : 'violet'}">${icon(parakeet ? 'audio-lines' : 'file-text')}</span><div><h3>${esc(model.name.replace(' · multilingual', ''))}${parakeet || model.id === 'tiny' ? `<span class="tag">${parakeet ? 'Multilingual' : 'Quick setup'}</span>` : ''}</h3><p>${parakeet ? 'NVIDIA · ONNX · On-device · 25 languages' : 'OpenAI Whisper · On-device · Multilingual'}</p></div><span class="model-state"><span class="dot ${installed ? 'ready' : ''}"></span>${installed ? 'Ready' : 'Not installed'}</span><div class="model-row-actions">${modelAction(model)}${installed ? button('remove-model', icon('trash-2'), 'icon-button danger', `data-id="${model.id}" aria-label="Remove ${esc(model.name)}"`) : ''}</div><span class="model-size">${modelSize(model.bytes)}</span></article>`;
}

function modelsView() {
  const current = state.models.find(model => model.id === state.data.preferences.model) ?? state.models[0];
  const recommendation = state.models.find(model => model.id === 'parakeet') ?? current;
  return `<div class="content-shell models-page">${eyebrowHeader('The engine room', 'AI models.', 'Choose the local model that gives your words their shape.')}<section class="current-model"><span class="model-icon">${icon('audio-lines')}</span><div><small>Currently using</small><strong>${esc(current?.name ?? 'No model selected')}</strong></div><span class="tag">${current?.id === 'parakeet' ? 'PARAKEET' : 'WHISPER'}</span><span class="model-state"><span class="dot ${state.ready ? 'ready' : ''}"></span>${state.ready ? 'ACTIVE' : 'LOADING'}</span></section>${state.settingUp ? `<section class="setup-progress" role="status"><div><strong id="model-progress">${esc(progress || 'Preparing your model…')}</strong><progress aria-label="Model setup"></progress></div>${button('cancel-setup', 'Cancel setup')}</section>` : ''}<section class="recommended-model"><div><p class="eyebrow">${icon('sparkles')} Recommended for you</p><h2>${esc(recommendation?.name ?? '')}</h2><div class="tags"><span class="tag">Multilingual</span><span class="tag">${recommendation ? modelSize(recommendation.bytes) : ''}</span></div><p>${recommendation?.id === 'parakeet' ? 'NVIDIA · ONNX · On-device · 25 languages' : 'OpenAI Whisper · On-device · Multilingual'}</p>${recommendation ? modelAction(recommendation, true) : ''}</div><div class="performance"><strong>How it performs</strong><span>Speed</span><div class="score">${'<i></i>'.repeat(7)}${'<b></b>'.repeat(3)}</div><span>Accuracy</span><div class="score">${'<i></i>'.repeat(9)}<b></b></div></div></section><section class="surface-card model-catalog"><h2>Model catalog</h2><p>Download once, then keep your voice on this PC.</p><h3>Parakeet — NVIDIA · fast, near-Whisper accuracy</h3>${state.models.filter(model => model.id === 'parakeet').map(modelRow).join('')}<h3>Whisper — OpenAI · established multilingual recognition</h3>${state.models.filter(model => model.id !== 'parakeet').map(modelRow).join('')}</section></div>`;
}

function settingsTabs() {
  return `<div class="settings-tabs" role="tablist">${([['general', 'sliders-horizontal', 'General'], ['audio', 'audio-lines', 'Audio'], ['permissions', 'shield-check', 'Permissions']] as [SettingsTab, string, string][]).map(([tab, glyph, label]) => `<button data-action="settings-tab" data-id="${tab}" role="tab" aria-selected="${settingsTab === tab}">${icon(glyph)}${label}</button>`).join('')}</div>`;
}

function settingsGeneral() {
  const preferences = state.data.preferences;
  const shortcut = preferences.shortcut;
  return `<form id="settings-form"><section class="settings-card">${cardHeader('palette', 'Appearance', 'Color Index is the Dictate identity. This controls the system appearance only.')}<div class="setting-row"><div><strong>Appearance</strong><small>Follow Windows, or choose a theme. Changes save automatically.</small></div>${segments('appearance', [['system', 'System'], ['light', 'Light'], ['dark', 'Dark']], preferences.appearance)}</div></section><section class="settings-card">${cardHeader('keyboard', 'Shortcut', 'Hold the key while speaking; release it to finish.')}<div class="setting-row"><div><strong>Push-to-talk key</strong><small>Choose one key, a combination, or a mouse button.</small></div><button type="button" data-action="capture-shortcut" class="shortcut-capture ${capturing ? 'capturing' : ''}"><span>${capturing ? 'Press a key or mouse button…' : esc(shortcutLabel(shortcut))}</span>${icon('chevron-down')}</button></div><div class="platform-tip">${icon('mouse')}<div><strong>Make Dictate comfortable to reach</strong><small>Try Right Ctrl, F8, or a middle/side mouse button. Escape cancels capture.</small></div><div class="preset-row">${[['ControlRight', 'Right Ctrl'], ['F8', 'F8'], ['MouseBack', 'Mouse back']].map(([value, label]) => button('shortcut-preset', label, 'link-button', `data-id="${value}"`)).join('')}</div></div><div class="setting-row"><div><strong>Recording behavior</strong><small>${preferences.recordingMode === 'holdToTalk' ? 'Hold the shortcut to speak; release it to finish.' : 'Press once to start; press again to finish.'}</small></div>${segments('recordingMode', [['holdToTalk', 'Hold to talk'], ['clickToToggle', 'Click to toggle']], preferences.recordingMode)}</div></section><section class="settings-card">${cardHeader('sliders-horizontal', 'General', 'Small choices that keep Dictate quiet, focused, and ready.')}<label class="setting-row"><div><strong>Show ready indicator</strong><small>Keep a small recorder visible between dictations.</small></div><input class="switch" name="showReadyIndicator" type="checkbox" role="switch" ${preferences.showReadyIndicator ? 'checked' : ''}></label><label class="setting-row"><div><strong>Keep history</strong><small>History, dictionary entries, and preferences stay on this PC. Raw audio is never stored.</small></div><input class="switch" name="keepHistory" type="checkbox" role="switch" ${preferences.keepHistory ? 'checked' : ''}></label><div class="setting-row"><div><strong>Retention</strong></div>${segments('retention', [['oneDay', 'One day'], ['oneWeek', 'One week'], ['oneMonth', 'One month'], ['forever', 'Forever']], preferences.retention)}</div><div class="setting-row"><div><strong>Delete all history</strong><small>Dictionary, models, and preferences remain.</small></div>${button('clear-history', 'Delete', 'danger')}</div></section><section class="settings-card">${cardHeader('info', 'About', 'Dictate updates are distributed with the app build.')}<div class="about-row"><p>Dictate is a private, local writing instrument for short spoken fragments.</p><span>Dictate ${esc(state.version)} · Windows</span></div><div class="setting-row"><div><strong>Review onboarding</strong><small>Walk through microphone and insertion setup again.</small></div>${button('show-setup', 'Review onboarding')}</div></section></form>`;
}

function settingsAudio() {
  const selected = state.models.find(model => model.id === state.data.preferences.model);
  return `<section class="settings-card">${cardHeader('audio-lines', 'Recording & Models', 'Choose the microphone and recognition engine behind each session.')}<div class="setting-row"><div><strong>Microphone</strong><small>Dictate captures only while a recording session is active.</small></div><span class="permission-status"><span class="dot ready"></span>Available</span></div><div class="setting-row"><div><strong>Transcription model</strong><small>${selected?.id === 'parakeet' ? 'NVIDIA · ONNX · On-device · 25 languages' : 'OpenAI Whisper · On-device · Multilingual'}</small></div><button data-section="models">${esc(selected?.name ?? 'Choose a model')}${icon('chevron-right')}</button></div></section><section class="settings-card">${cardHeader('cpu', 'Local models', 'Download once, then keep your voice on this PC.')}<div class="settings-models">${state.models.map(modelRow).join('')}</div></section>`;
}

function settingsPermissions() {
  const preferences = state.data.preferences;
  return `<form id="settings-form"><section class="settings-card">${cardHeader('lock-keyhole', 'Insertion & Permissions', 'Dictate returns words to the focused text field. Changes save automatically.')}<label class="setting-row"><div><strong>Insert words at your cursor</strong><small>Uses Windows text input in the external field that has keyboard focus.</small></div><input class="switch" name="autoInsert" type="checkbox" role="switch" ${preferences.autoInsert ? 'checked' : ''}></label><div class="setting-row"><div><strong>Microphone</strong><small>Required to hear your voice on this PC.</small></div><span class="permission-status"><span class="dot ready"></span>Windows managed</span></div></section><section class="settings-card">${cardHeader('shield-check', 'Privacy', 'History, dictionary entries, and preferences stay on this PC. Raw audio is never stored.')}<div class="privacy-copy"><strong>Stored on this PC</strong><p>History and dictionary entries use local app data. Preferences and pending recovery text also remain local.</p>${button('open-privacy', 'Read the privacy policy', 'link-button privacy-link')}</div><label class="setting-row"><div><strong>Keep history</strong><small>Turn this off when you do not want completed transcripts saved.</small></div><input class="switch" name="keepHistory" type="checkbox" role="switch" ${preferences.keepHistory ? 'checked' : ''}></label><div class="setting-row"><div><strong>Retention</strong></div>${segments('retention', [['oneDay', 'One day'], ['oneWeek', 'One week'], ['oneMonth', 'One month'], ['forever', 'Forever']], preferences.retention)}</div></section></form>`;
}

function settingsView() {
  return `<div class="content-shell settings-page">${eyebrowHeader('Control room', 'Settings', 'Tune Dictate around the way you speak and write.')}${settingsTabs()}${settingsTab === 'general' ? settingsGeneral() : settingsTab === 'audio' ? settingsAudio() : settingsPermissions()}</div>`;
}

function setupAction() {
  if (state.settingUp) return `<div class="download-progress"><strong id="model-progress">${esc(progress || 'Preparing your model…')}</strong><progress aria-label="Model setup"></progress>${button('cancel-setup', 'Cancel setup', 'link-button')}</div>`;
  if (state.ready) return `<span class="permission-status"><span class="dot ready"></span>Ready</span>`;
  return button('setup', 'Download and use model', 'primary');
}

function onboarding() {
  const model = state.models.find(item => item.id === state.data.preferences.model) ?? state.models[0];
  if (showSetupOptions) return `<div class="onboarding-backdrop"><section class="onboarding-panel options"><header><div><h2>Make Dictate yours</h2><p>Choose a local model and how you start recording.</p></div>${button('close-setup-options', 'Done')}</header><div class="setting-row"><div><strong>Speech model</strong><small>All available models run locally on your CPU.</small></div><button data-action="browse-models">${esc(model?.name ?? 'Choose a model')}${icon('chevron-right')}</button></div><div class="setting-row"><div><strong>Recording shortcut</strong><small>Change this any time in Settings.</small></div><span class="shortcut-pill">${esc(shortcutLabel(state.data.preferences.shortcut))}</span></div><div class="setting-row"><div><strong>Recording behavior</strong></div>${segments('setupMode', [['holdToTalk', 'Hold to talk'], ['clickToToggle', 'Click to toggle']], state.data.preferences.recordingMode)}</div></section></div>`;
  return `<div class="onboarding-backdrop"><section class="onboarding-panel"><header class="onboarding-brand"><div class="brand-inline">${brandMark()}<strong>Dictate</strong></div><span>Private on your PC · Free</span></header><div class="onboarding-title"><h2>${state.ready ? 'Ready for your first words' : 'Make room for your voice'}</h2><p>A microphone, a speech model, and you. No account needed.</p></div><div class="onboarding-steps"><div>${icon('mic')}<span><strong>Allow your microphone</strong><small>Your recording is processed on this PC.</small></span><span class="permission-status"><span class="dot ready"></span>Windows managed</span></div><div>${icon('audio-lines')}<span><strong>${esc(model?.name ?? 'Local speech model')}</strong><small>Parakeet downloads automatically on first launch (670 MB). No NVIDIA GPU needed. You can cancel or choose another model in Setup options.</small></span>${setupAction()}</div><div>${icon('mouse')}<span><strong>Insert words at your cursor</strong><small>Dictate types into the external field that has keyboard focus. If it cannot, your words stay ready to copy.</small></span><span class="permission-status"><span class="dot ${state.data.preferences.autoInsert ? 'ready' : ''}"></span>${state.data.preferences.autoInsert ? 'Ready' : 'Off'}</span></div></div><footer><div>${button('setup-options', 'Setup options', 'link-button')}${button('open-privacy', 'Privacy', 'link-button')}</div><div>${button('complete-setup', 'Explore first', 'link-button')}${button('complete-setup', 'Start using Dictate', 'primary', state.ready ? '' : 'disabled')}</div></footer></section></div>`;
}

function render() {
  const restoreUI = state ? preserveUI() : () => {};
  const theme = state.data.preferences.appearance;
  document.documentElement.dataset.theme = theme === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : theme;
  if (overlay) {
    const active = ['preparing', 'listening'].includes(state.phase);
    const processing = ['finalizing', 'delivering'].includes(state.phase);
    const signal = active
      ? `<div class="pebble-bars" aria-hidden="true">${Array.from({ length: 9 }, (_, index) => `<i class="pebble-bar" style="--index:${index}"></i>`).join('')}</div>`
      : processing ? '<div class="pebble-dots" aria-hidden="true"><i></i><i></i><i></i></div>'
        : state.phase === 'failed' ? '<span class="pebble-failure" aria-hidden="true">!</span>'
          : '<div class="pebble-ready" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></div>';
    root.innerHTML = `<div class="recording-overlay ${active ? 'active' : processing ? 'processing' : state.phase === 'idle' ? 'idle' : ''}" role="status" aria-label="${esc(status())}">${signal}</div>`;
    document.body.classList.add('overlay'); return;
  }
  const views: Record<Section, () => string> = { dashboard, history: historyView, dictionary: dictionaryView, statistics: statisticsView, models: modelsView, settings: settingsView };
  root.innerHTML = `${sidebar()}<div class="main-frame">${feedback()}${views[section]()}${state.shortcutError ? `<p class="shortcut-notice">${esc(state.shortcutError)}</p>` : ''}</div>${!state.data.preferences.onboardingDone ? onboarding() : ''}`;
  createIcons({ icons: allIcons }); bindForms(); restoreUI();
  const input = root.querySelector<HTMLInputElement>('#search');
  input?.addEventListener('input', () => { search = input.value; const position = input.selectionStart; render(); const next = root.querySelector<HTMLInputElement>('#search'); next?.focus(); next?.setSelectionRange(position, position); });
}

root.addEventListener('click', async event => {
  const buttonElement = (event.target as Element).closest<HTMLButtonElement>('button');
  if (!buttonElement || buttonElement.disabled) return;
  if (capturing && buttonElement.dataset.section) await stopCapture();
  if (buttonElement.dataset.section) {
    section = buttonElement.dataset.section as Section; search = ''; editing = null; showSetupOptions = false;
    if (!state.data.preferences.onboardingDone) await savePreference({ onboardingDone: true }); else render();
    root.querySelector<HTMLHeadingElement>('h1')?.focus({ preventScroll: true }); return;
  }
  const action = buttonElement.dataset.action; const id = buttonElement.dataset.id;
  if (action === 'reload') { location.reload(); return; }
  if (capturing && action !== 'capture-shortcut') await stopCapture();
  const history = state.data.history; const entries = state.data.dictionary;
  switch (action) {
    case 'history-day': selectedDay = id!; render(); break;
    case 'toggle-history': expandedHistory = expandedHistory === id ? null : id!; render(); break;
    case 'clear-search': search = ''; render(); break;
    case 'settings-tab': settingsTab = id as SettingsTab; resetDrafts.add('settings-form'); render(); break;
    case 'add-entry': editing = 'new'; resetDrafts.add('dictionary-form'); render(); break;
    case 'edit-entry': editing = id!; resetDrafts.add('dictionary-form'); render(); break;
    case 'cancel-edit': editing = null; resetDrafts.add('dictionary-form'); render(); break;
    case 'setup-options': showSetupOptions = true; render(); break;
    case 'close-setup-options': showSetupOptions = false; render(); break;
    case 'capture-shortcut': if (capturing) await stopCapture(); else { try { await invoke('pause_shortcut', { paused: true }); capturing = true; modifierCandidate = ''; render(); } catch (error) { localError = String(error); render(); } } break;
    case 'shortcut-preset': await savePreference({ shortcut: id! }); break;
    case 'open-privacy': try { await openUrl(privacyURL); } catch (error) { localError = `Privacy page could not open: ${String(error)}`; render(); } break;
    case 'record': await call('start_recording'); break;
    case 'finish': await call('finish_recording'); break;
    case 'cancel-recording': try { await invoke('cancel_recording'); } catch (error) { localError = String(error); } await refresh(); break;
    case 'setup': await call('setup_model', { id: state.data.preferences.model, download: true }); break;
    case 'select-model': await call('setup_model', { id, download: !state.installed.includes(id!) }); break;
    case 'browse-models': await savePreference({ onboardingDone: true }); section = 'models'; showSetupOptions = false; render(); break;
    case 'cancel-setup': await invoke('cancel_setup'); break;
    case 'remove-model': if (await confirm('Remove this downloaded model? You can download it again later.', { title: 'Remove model', kind: 'warning' })) await call('remove_model', { id }); break;
    case 'complete-setup': await savePreference({ onboardingDone: true }); break;
    case 'show-setup': await savePreference({ onboardingDone: false }); break;
    case 'copy-recovery': await call('copy_text', { text: state.data.recovery }); break;
    case 'discard-recovery': if (await confirm('Discard this recovered transcript?', { title: 'Discard transcript', kind: 'warning' })) await call('discard_recovery'); break;
    case 'retry-delivery': await call('retry_delivery'); break;
    case 'copy-history': await call('copy_text', { text: history.find(item => item.id === id)?.correctedText }); break;
    case 'pin-history': await call('update_history', { id, action: 'pin' }); break;
    case 'delete-history': if (await confirm('Delete this transcript from history?', { title: 'Delete transcript', kind: 'warning' })) await call('update_history', { id, action: 'delete' }); break;
    case 'clear-history': if (await confirm('Delete all history? Dictionary, models, and pending recovery remain.', { title: 'Delete history', kind: 'warning' })) await call('update_history', { id: null, action: 'clear' }); break;
    case 'toggle-entry': await call('save_dictionary', { entries: entries.map(entry => entry.id === id ? { ...entry, isEnabled: !entry.isEnabled, updatedAt: new Date().toISOString() } : entry) }); break;
    case 'delete-entry': if (await confirm('Remove this dictionary rule?', { title: 'Remove rule', kind: 'warning' })) await call('save_dictionary', { entries: entries.filter(entry => entry.id !== id) }); break;
    case 'export-history': { const path = await save({ defaultPath: 'dictate-history.json', filters: [{ name: 'JSON', extensions: ['json'] }] }); if (path) await call('export_data', { path, kind: 'history' }); break; }
    case 'export-dictionary': { const path = await save({ defaultPath: 'dictate-dictionary.json', filters: [{ name: 'JSON', extensions: ['json'] }] }); if (path) await call('export_data', { path, kind: 'dictionary' }); break; }
    case 'import-dictionary': { const path = await open({ multiple: false, directory: false, filters: [{ name: 'Dictionary JSON', extensions: ['json'] }] }); if (path) await call('import_dictionary', { path }); break; }
  }
});

function bindForms() {
  root.querySelectorAll<HTMLInputElement>('input[name="statsRange"]').forEach(input => input.addEventListener('change', () => { statsRange = input.value as typeof statsRange; render(); }));
  root.querySelectorAll<HTMLInputElement>('input[name="setupMode"]').forEach(input => input.addEventListener('change', () => { void savePreference({ recordingMode: input.value }); }));
  root.querySelector<HTMLFormElement>('#dictionary-form')?.addEventListener('submit', async event => {
    event.preventDefault(); const form = new FormData(event.target as HTMLFormElement); const kind = String(form.get('kind')); const prior = state.data.dictionary.find(entry => entry.id === editing);
    const entry: Entry = { id: prior?.id ?? crypto.randomUUID(), kind, sourcePhrase: String(form.get('source')).trim(), targetPhrase: kind === 'correction' ? String(form.get('target')).trim() : null, notes: prior?.notes ?? null, isEnabled: prior?.isEnabled ?? true, createdAt: prior?.createdAt ?? new Date().toISOString(), updatedAt: new Date().toISOString() };
    await call('save_dictionary', { entries: [...state.data.dictionary.filter(item => item.id !== entry.id), entry] }, 'dictionary-form'); if (!localError) { editing = null; resetDrafts.add('dictionary-form'); render(); }
  });
  root.querySelector<HTMLFormElement>('#settings-form')?.addEventListener('change', event => {
    const input = event.target as HTMLInputElement;
    if (!input.name || (input.type === 'radio' && !input.checked)) return;
    const value = input.type === 'checkbox' ? input.checked : input.value;
    void savePreference({ [input.name]: value } as Partial<Preferences>);
  });
}

async function stopCapture(value?: string) {
  capturing = false; modifierCandidate = '';
  try { await invoke('pause_shortcut', { paused: false }); } catch (error) { localError = String(error); }
  if (value) await savePreference({ shortcut: value }); else render();
  root.querySelector<HTMLButtonElement>('[data-action="capture-shortcut"]')?.focus();
}
function combination(event: KeyboardEvent | MouseEvent, code: string) { return [event.ctrlKey ? 'Ctrl' : '', event.altKey ? 'Alt' : '', event.shiftKey ? 'Shift' : '', event.metaKey ? 'Win' : '', code].filter(Boolean).join('+'); }
window.addEventListener('keydown', event => { if (!capturing) { if (event.key === 'Escape' && state?.phase !== 'idle') void invoke('cancel_recording').catch(() => {}); return; } event.preventDefault(); event.stopImmediatePropagation(); if (event.repeat) return; if (event.code === 'Escape') { void stopCapture(); return; } if (/^(Control|Alt|Shift|Meta)(Left|Right)$/.test(event.code)) { modifierCandidate = event.code; return; } if (event.code) void stopCapture(combination(event, event.code)); }, true);
window.addEventListener('keyup', event => { if (capturing && event.code === modifierCandidate) { event.preventDefault(); event.stopImmediatePropagation(); void stopCapture(event.code); } }, true);
window.addEventListener('mousedown', event => { if (!capturing || ![1, 3, 4].includes(event.button)) return; event.preventDefault(); event.stopImmediatePropagation(); capturedMouse = event.button; void stopCapture(combination(event, ({ 1: 'MouseMiddle', 3: 'MouseBack', 4: 'MouseForward' } as Record<number, string>)[event.button])); }, true);
window.addEventListener('auxclick', event => { if (capturing || event.button === capturedMouse) { event.preventDefault(); event.stopImmediatePropagation(); capturedMouse = null; } }, true);
window.addEventListener('blur', () => { if (capturing) void stopCapture(); });
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => { if (state?.data.preferences.appearance === 'system') render(); });

async function initialize() {
  await listen('state-changed', () => { void refresh(); });
  await listen<{ progress: number; stage: string }>('model-progress', event => { progress = event.payload.stage === 'loading' ? 'Download verified. Loading local model…' : `Downloading: ${Math.round(event.payload.progress * 100)}%`; const statusElement = root.querySelector('#model-progress'); if (statusElement && state?.settingUp) statusElement.textContent = progress; });
  await listen<number>('level', event => {
    const rms = Number.isFinite(event.payload) ? event.payload : 0;
    const level = Math.pow(Math.min(1, Math.max(0, rms - .002) / .08), .55);
    document.querySelectorAll<HTMLElement>('.pebble-bar').forEach((bar, index) => {
      const motion = .35 + .65 * Math.abs(Math.sin(performance.now() / 130 + index * .82));
      bar.style.height = `${Math.max(3, 3 + 9 * level * motion)}px`;
      bar.style.opacity = String(.52 + level * .48);
    });
  });
  await refresh();
}
void initialize().catch(error => { root.innerHTML = `<main class="startup"><h1>Dictate could not connect</h1><p>${esc(error)}</p></main>`; });
