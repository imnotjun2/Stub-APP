import {
  ArchiveIcon,
  CalendarIcon,
  CameraIcon,
  CardStackPlusIcon,
  CheckCircledIcon,
  CheckIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  Cross2Icon,
  DashboardIcon,
  DotsHorizontalIcon,
  DownloadIcon,
  DrawingPinIcon,
  GlobeIcon,
  HomeIcon,
  ImageIcon,
  ListBulletIcon,
  LockClosedIcon,
  MagicWandIcon,
  MixerHorizontalIcon,
  MoonIcon,
  PaperPlaneIcon,
  Pencil2Icon,
  PersonIcon,
  PlusIcon,
  ReaderIcon,
  SunIcon,
  TrashIcon,
} from "@radix-ui/react-icons";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  BottomSheet,
  Carousel,
  KeyboardInput,
  KeyboardTextarea,
  MobileScroll,
  useKeyboard,
} from "./mobile";

type MainTab = "home" | "trips" | "wall" | "profile";
type Page = MainTab | "import" | "review" | "detail" | "tripBook";
type Locale = "zh" | "en";
type ThemeSetting = "system" | "light" | "dark";
type CategoryId = "movie" | "travel" | "exhibition" | "food" | "shopping" | "other";
type TravelSubtype = "flight" | "train" | "unknown";
type MediaRole = "ticket" | "memory-photo" | "poster" | "trip-cover";

type MovieDetails = {
  kind: "movie";
  filmTitle: string;
  cinema: string;
  hall: string;
  seat: string;
  formatIds: string[];
};

type FlightDetails = {
  kind: "flight";
  airline: string;
  airlineCode: string;
  flightNumber: string;
  aircraft: string;
  cabin: string;
  seat: string;
  departure: string;
  arrival: string;
  departureTime: string;
  arrivalTime: string;
};

type TrainDetails = {
  kind: "train";
  operator: string;
  trainNumber: string;
  seatClass: string;
  coach: string;
  seat: string;
  departure: string;
  arrival: string;
  departureTime: string;
};

type GenericDetails = {
  kind: "generic";
  location: string;
};

type StubDetails = MovieDetails | FlightDetails | TrainDetails | GenericDetails;

type StubRecord = {
  schemaVersion: 2;
  id: string;
  source: "user" | "sample";
  title: string;
  titleEn?: string;
  occurredOn: string;
  category: CategoryId;
  subtype?: TravelSubtype;
  note: string;
  noteEn?: string;
  tags: string[];
  primaryMediaId: string;
  attachmentIds: string[];
  posterMediaId?: string;
  details: StubDetails;
  createdAt: string;
  updatedAt: string;
};

type MediaAsset = {
  id: string;
  role: MediaRole;
  source: "upload" | "bundled";
  blob?: Blob;
  url?: string;
  name?: string;
  createdAt: string;
};

type TripBook = {
  id: string;
  source: "user" | "sample";
  title: string;
  titleEn?: string;
  startDate: string;
  endDate: string;
  route: string;
  routeEn?: string;
  note: string;
};

type TripItem = {
  id: string;
  tripId: string;
  stubId: string;
  order: number;
  day: number;
  caption: string;
  rotation: number;
  scale: number;
};

type LegacyStub = {
  id: string;
  title: string;
  date: string;
  type: "电影" | "旅行" | "展览" | "餐饮" | "购物" | "其他";
  note: string;
  image: string;
  userCreated?: boolean;
};

type PendingMedia = {
  id: string;
  role: MediaRole;
  blob: Blob;
  preview: string;
  name: string;
  ownsPreview: boolean;
};

type DraftStub = {
  editingId: string | null;
  originalAttachmentIds: string[];
  originalPosterMediaId?: string;
  title: string;
  date: string;
  category: CategoryId;
  subtype: TravelSubtype;
  note: string;
  tags: string[];
  tagInput: string;
  primary: PendingMedia | null;
  attachments: PendingMedia[];
  poster: PendingMedia | null;
  useSuggestedPoster: boolean;
  movieFormats: string[];
  movieCinema: string;
  movieHall: string;
  movieSeat: string;
  airline: string;
  airlineCode: string;
  flightNumber: string;
  aircraft: string;
  cabin: string;
  flightSeat: string;
  departure: string;
  arrival: string;
  departureTime: string;
  arrivalTime: string;
  trainOperator: string;
  trainNumber: string;
  trainClass: string;
  trainCoach: string;
  trainSeat: string;
  location: string;
  tripId: string;
};

type LibraryState = {
  db: IDBDatabase;
  records: StubRecord[];
  media: MediaAsset[];
  trips: TripBook[];
  tripItems: TripItem[];
  migrated: number;
};

const LEGACY_KEY = "stub-demo-user-entries-v1";
const DB_NAME = "stub-demo";
const DB_VERSION = 1;
const MIGRATION_KEY = "migration.stub-v1.complete";
const THEME_KEY = "stub-demo-theme-v2";
const LOCALE_KEY = "stub-demo-locale-v2";

const categoryIds: CategoryId[] = ["movie", "travel", "exhibition", "food", "shopping", "other"];
const movieFormats = ["imax", "dolby-cinema", "cinity", "4dx"];
const suggestedTags = [
  { id: "tag.premiere", zh: "首映", en: "Premiere" },
  { id: "tag.with-friends", zh: "和朋友", en: "With friends" },
  { id: "tag.solo-trip", zh: "独自出发", en: "Solo trip" },
  { id: "tag.rainy-day", zh: "雨天", en: "Rainy day" },
  { id: "tag.rewatch", zh: "值得重温", en: "Rewatch" },
  { id: "tag.delicious", zh: "好吃", en: "Delicious" },
] as const;

const localPosterCandidates = [
  {
    mediaId: "media-seed-movie-poster",
    src: "/stub-assets/movie-poster-pentagram.jpg",
    titleZh: "名侦探柯南：百万美元的五棱星",
    titleEn: "Detective Conan: The Million-dollar Pentagram",
    aliases: ["名侦探柯南", "百万美元的五棱星", "detective conan", "million dollar pentagram", "million-dollar pentagram"],
  },
] as const;

const bundledAirlineLogos: Record<string, string> = {
  MU: "/stub-assets/airline-mu.png",
  CA: "/stub-assets/airline-ca.png",
  CZ: "/stub-assets/airline-cz.png",
};

function posterCandidateFor(title: string) {
  const normalized = title.trim().toLocaleLowerCase().replace(/[：:·・—–_]/g, " ").replace(/\s+/g, " ");
  if (!normalized) return null;
  return localPosterCandidates.find((candidate) => candidate.aliases.some((alias) => normalized.includes(alias))) ?? null;
}

function airlineLogoFor(code: string) {
  return bundledAirlineLogos[code.trim().toUpperCase()] ?? null;
}

function getLocalDate() {
  const today = new Date();
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(today);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function makeEmptyDraft(): DraftStub {
  return {
    editingId: null,
    originalAttachmentIds: [],
    originalPosterMediaId: undefined,
    title: "",
    date: getLocalDate(),
    category: "other",
    subtype: "unknown",
    note: "",
    tags: [],
    tagInput: "",
    primary: null,
    attachments: [],
    poster: null,
    useSuggestedPoster: true,
    movieFormats: [],
    movieCinema: "",
    movieHall: "",
    movieSeat: "",
    airline: "",
    airlineCode: "",
    flightNumber: "",
    aircraft: "",
    cabin: "economy",
    flightSeat: "",
    departure: "",
    arrival: "",
    departureTime: "",
    arrivalTime: "",
    trainOperator: "",
    trainNumber: "",
    trainClass: "second",
    trainCoach: "",
    trainSeat: "",
    location: "",
    tripId: "",
  };
}

const seedMedia: MediaAsset[] = [
  {
    id: "media-seed-movie-ticket",
    role: "ticket",
    source: "bundled",
    url: "/reference-crops/movie-ticket-reference.png",
    createdAt: "2026-08-10T12:00:00.000Z",
  },
  {
    id: "media-seed-movie-poster",
    role: "poster",
    source: "bundled",
    url: "/stub-assets/movie-poster-pentagram.jpg",
    createdAt: "2026-08-10T12:00:00.000Z",
  },
  {
    id: "media-seed-flight-ticket",
    role: "ticket",
    source: "bundled",
    url: "/reference-crops/boarding-pass-reference.png",
    createdAt: "2026-08-03T01:00:00.000Z",
  },
  {
    id: "media-seed-train-ticket",
    role: "ticket",
    source: "bundled",
    url: "/reference-crops/train-ticket-reference.png",
    createdAt: "2026-08-01T02:00:00.000Z",
  },
  {
    id: "media-seed-food-photo",
    role: "memory-photo",
    source: "bundled",
    url: "/stub-assets/hokkaido-ramen.jpg",
    createdAt: "2026-08-06T11:30:00.000Z",
  },
];

const seedRecords: StubRecord[] = [
  {
    schemaVersion: 2,
    id: "seed-movie",
    source: "sample",
    title: "名侦探柯南：百万美元的五棱星",
    titleEn: "Detective Conan: The Million-dollar Pentagram",
    occurredOn: "2026-08-10",
    category: "movie",
    note: "和你一起看柯南首映的夜晚，散场时外面还在下雨。",
    noteEn: "The premiere ended while the rain was still falling outside.",
    tags: ["tag.premiere", "tag.rainy-day"],
    primaryMediaId: "media-seed-movie-ticket",
    attachmentIds: [],
    posterMediaId: "media-seed-movie-poster",
    details: {
      kind: "movie",
      filmTitle: "名侦探柯南：百万美元的五棱星",
      cinema: "CGV影城 合生汇店",
      hall: "6号厅",
      seat: "E07",
      formatIds: ["imax"],
    },
    createdAt: "2026-08-10T12:00:00.000Z",
    updatedAt: "2026-08-10T12:00:00.000Z",
  },
  {
    schemaVersion: 2,
    id: "seed-flight",
    source: "sample",
    title: "上海虹桥 → 札幌新千岁",
    titleEn: "Shanghai Hongqiao → Sapporo New Chitose",
    occurredOn: "2026-08-03",
    category: "travel",
    subtype: "flight",
    note: "夏天从一张登机牌开始。",
    noteEn: "Summer began with a boarding pass.",
    tags: ["tag.solo-trip"],
    primaryMediaId: "media-seed-flight-ticket",
    attachmentIds: [],
    details: {
      kind: "flight",
      airline: "中国东方航空",
      airlineCode: "MU",
      flightNumber: "MU5237",
      aircraft: "Airbus A320neo",
      cabin: "economy",
      seat: "12A",
      departure: "SHA",
      arrival: "CTS",
      departureTime: "08:25",
      arrivalTime: "13:05",
    },
    createdAt: "2026-08-03T01:00:00.000Z",
    updatedAt: "2026-08-03T01:00:00.000Z",
  },
  {
    schemaVersion: 2,
    id: "seed-food",
    source: "sample",
    title: "札幌雨夜的味噌拉面",
    titleEn: "Miso ramen on a rainy Sapporo night",
    occurredOn: "2026-08-06",
    category: "food",
    note: "窗外是雨，汤里是很长的一天。",
    noteEn: "Rain outside, and a very long day held in the broth.",
    tags: ["tag.delicious", "tag.rainy-day"],
    primaryMediaId: "media-seed-food-photo",
    attachmentIds: [],
    details: { kind: "generic", location: "札幌 · 狸小路" },
    createdAt: "2026-08-06T11:30:00.000Z",
    updatedAt: "2026-08-06T11:30:00.000Z",
  },
  {
    schemaVersion: 2,
    id: "seed-train",
    source: "sample",
    title: "杭州东 → 苏州",
    titleEn: "Hangzhoudong → Suzhou",
    occurredOn: "2026-08-01",
    category: "travel",
    subtype: "train",
    note: "去见朋友，也路过西湖。",
    noteEn: "A train to see a friend, passing the lake on the way.",
    tags: ["tag.with-friends"],
    primaryMediaId: "media-seed-train-ticket",
    attachmentIds: [],
    details: {
      kind: "train",
      operator: "中国铁路",
      trainNumber: "G7501",
      seatClass: "second",
      coach: "02",
      seat: "08A",
      departure: "杭州东",
      arrival: "苏州",
      departureTime: "10:15",
    },
    createdAt: "2026-08-01T02:00:00.000Z",
    updatedAt: "2026-08-01T02:00:00.000Z",
  },
];

const seedTrip: TripBook = {
  id: "trip-hokkaido",
  source: "sample",
  title: "札幌 · 2026 夏",
  titleEn: "Sapporo · Summer 2026",
  startDate: "2026-08-03",
  endDate: "2026-08-10",
  route: "上海—札幌",
  routeEn: "Shanghai—Sapporo",
  note: "雨、拉面和几张舍不得丢掉的纸。",
};

const seedTripItems: TripItem[] = [
  {
    id: "trip-item-flight",
    tripId: seedTrip.id,
    stubId: "seed-flight",
    order: 1,
    day: 1,
    caption: "抵达",
    rotation: -0.5,
    scale: 1,
  },
  {
    id: "trip-item-food",
    tripId: seedTrip.id,
    stubId: "seed-food",
    order: 2,
    day: 4,
    caption: "雨夜",
    rotation: 0.8,
    scale: 1,
  },
];

function requestResult<T>(request: IDBRequest<T>) {
  return new Promise<T>((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("IndexedDB request failed"));
  });
}

function transactionDone(transaction: IDBTransaction) {
  return new Promise<void>((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onabort = () => reject(transaction.error ?? new Error("IndexedDB transaction aborted"));
    transaction.onerror = () => reject(transaction.error ?? new Error("IndexedDB transaction failed"));
  });
}

function openDatabase() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = window.indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains("records")) db.createObjectStore("records", { keyPath: "id" });
      if (!db.objectStoreNames.contains("media")) db.createObjectStore("media", { keyPath: "id" });
      if (!db.objectStoreNames.contains("trips")) db.createObjectStore("trips", { keyPath: "id" });
      if (!db.objectStoreNames.contains("tripItems")) db.createObjectStore("tripItems", { keyPath: "id" });
      if (!db.objectStoreNames.contains("settings")) db.createObjectStore("settings", { keyPath: "key" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("Unable to open local library"));
  });
}

function dataUrlToBlob(dataUrl: string) {
  const [meta, encoded] = dataUrl.split(",");
  if (!encoded) throw new Error("Invalid legacy image");
  const mime = meta.match(/data:([^;]+)/)?.[1] ?? "image/jpeg";
  const bytes = window.atob(encoded);
  const array = new Uint8Array(bytes.length);
  for (let index = 0; index < bytes.length; index += 1) array[index] = bytes.charCodeAt(index);
  return new Blob([array], { type: mime });
}

function legacyCategory(type: LegacyStub["type"]): CategoryId {
  const mapping: Record<LegacyStub["type"], CategoryId> = {
    电影: "movie",
    旅行: "travel",
    展览: "exhibition",
    餐饮: "food",
    购物: "shopping",
    其他: "other",
  };
  return mapping[type];
}

function readLegacyRecords() {
  try {
    const raw = window.localStorage.getItem(LEGACY_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as LegacyStub[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (item) => item && typeof item.id === "string" && typeof item.title === "string" && typeof item.image === "string",
    );
  } catch {
    return [];
  }
}

async function migrateLegacy(db: IDBDatabase) {
  const markerTransaction = db.transaction("settings", "readonly");
  const markerDone = transactionDone(markerTransaction);
  const markerRequest = requestResult<{ key: string; value: boolean } | undefined>(
    markerTransaction.objectStore("settings").get(MIGRATION_KEY),
  );
  const [marker] = await Promise.all([markerRequest, markerDone]);
  if (marker?.value) return 0;

  const legacy = readLegacyRecords();
  const converted = legacy.map((entry) => {
    const mediaId = `media-${entry.id}-ticket`;
    const category = legacyCategory(entry.type);
    const timestamp = new Date().toISOString();
    const record: StubRecord = {
      schemaVersion: 2,
      id: entry.id,
      source: "user",
      title: entry.title,
      occurredOn: entry.date || getLocalDate(),
      category,
      subtype: category === "travel" ? "unknown" : undefined,
      note: entry.note ?? "",
      tags: [],
      primaryMediaId: mediaId,
      attachmentIds: [],
      details: { kind: "generic", location: "" },
      createdAt: timestamp,
      updatedAt: timestamp,
    };
    const media: MediaAsset = {
      id: mediaId,
      role: "ticket",
      source: "upload",
      blob: dataUrlToBlob(entry.image),
      name: `${entry.title}.jpg`,
      createdAt: timestamp,
    };
    return { record, media };
  });

  if (converted.length) {
    const write = db.transaction(["records", "media"], "readwrite");
    const writeDone = transactionDone(write);
    converted.forEach(({ record, media }) => {
      write.objectStore("records").put(record);
      write.objectStore("media").put(media);
    });
    await writeDone;

    const verify = db.transaction(["records", "media"], "readonly");
    const verifyDone = transactionDone(verify);
    const verifiedRequests = Promise.all(
      converted.flatMap(({ record, media }) => [
        requestResult(verify.objectStore("records").get(record.id)),
        requestResult(verify.objectStore("media").get(media.id)),
      ]),
    );
    const [verified] = await Promise.all([verifiedRequests, verifyDone]);
    if (verified.some((item) => !item)) throw new Error("Legacy migration verification failed");
  }

  const finish = db.transaction("settings", "readwrite");
  const finishDone = transactionDone(finish);
  finish.objectStore("settings").put({ key: MIGRATION_KEY, value: true, count: converted.length });
  await finishDone;
  return converted.length;
}

async function getAllFromStore<T>(db: IDBDatabase, storeName: string) {
  const transaction = db.transaction(storeName, "readonly");
  const done = transactionDone(transaction);
  const valuesRequest = requestResult<T[]>(transaction.objectStore(storeName).getAll());
  const [values] = await Promise.all([valuesRequest, done]);
  return values;
}

async function loadLibrary(): Promise<LibraryState> {
  const db = await openDatabase();
  const migrated = await migrateLegacy(db);
  const [records, media, trips, tripItems] = await Promise.all([
    getAllFromStore<StubRecord>(db, "records"),
    getAllFromStore<MediaAsset>(db, "media"),
    getAllFromStore<TripBook>(db, "trips"),
    getAllFromStore<TripItem>(db, "tripItems"),
  ]);
  return { db, records, media, trips, tripItems, migrated };
}

async function saveRecordBundle(
  db: IDBDatabase,
  record: StubRecord,
  media: MediaAsset[],
  tripItem?: TripItem,
  removedMediaIds: string[] = [],
  removedTripItemIds: string[] = [],
) {
  const stores = tripItem || removedTripItemIds.length ? ["records", "media", "tripItems"] : ["records", "media"];
  const transaction = db.transaction(stores, "readwrite");
  const done = transactionDone(transaction);
  transaction.objectStore("records").put(record);
  media.forEach((asset) => transaction.objectStore("media").put(asset));
  removedMediaIds.forEach((id) => transaction.objectStore("media").delete(id));
  if (tripItem) transaction.objectStore("tripItems").put(tripItem);
  removedTripItemIds.forEach((id) => transaction.objectStore("tripItems").delete(id));
  await done;
}

async function saveTripBook(db: IDBDatabase, trip: TripBook) {
  const transaction = db.transaction("trips", "readwrite");
  const done = transactionDone(transaction);
  transaction.objectStore("trips").put(trip);
  await done;
}

async function saveTripItem(db: IDBDatabase, item: TripItem) {
  const transaction = db.transaction("tripItems", "readwrite");
  const done = transactionDone(transaction);
  transaction.objectStore("tripItems").put(item);
  await done;
}

async function deleteRecordBundle(db: IDBDatabase, record: StubRecord) {
  const currentItems = await getAllFromStore<TripItem>(db, "tripItems");
  const transaction = db.transaction(["records", "media", "tripItems"], "readwrite");
  const done = transactionDone(transaction);
  transaction.objectStore("records").delete(record.id);
  [record.primaryMediaId, record.posterMediaId, ...record.attachmentIds].filter(Boolean).forEach((id) => {
    transaction.objectStore("media").delete(id as string);
  });
  currentItems.filter((item) => item.stubId === record.id).forEach((item) => {
    transaction.objectStore("tripItems").delete(item.id);
  });
  await done;
}

function readAndResizeImage(file: File, role: MediaRole) {
  return new Promise<PendingMedia>((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("无法读取这张图片"));
    reader.onload = () => {
      const image = new Image();
      image.onerror = () => reject(new Error("暂时无法识别这个图片格式"));
      image.onload = () => {
        const maxEdge = role === "ticket" ? 1800 : 1600;
        const scale = Math.min(1, maxEdge / Math.max(image.width, image.height));
        const width = Math.max(1, Math.round(image.width * scale));
        const height = Math.max(1, Math.round(image.height * scale));
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const context = canvas.getContext("2d");
        if (!context) {
          reject(new Error("浏览器无法处理这张图片"));
          return;
        }
        context.fillStyle = "#fffdf8";
        context.fillRect(0, 0, width, height);
        context.drawImage(image, 0, 0, width, height);
        canvas.toBlob(
          (blob) => {
            if (!blob) {
              reject(new Error("图片压缩失败"));
              return;
            }
            const id = `media-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
            resolve({ id, role, blob, preview: URL.createObjectURL(blob), name: file.name, ownsPreview: true });
          },
          "image/jpeg",
          role === "ticket" ? 0.86 : 0.84,
        );
      };
      image.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

function formatDate(date: string, locale: Locale) {
  const parsed = new Date(`${date}T12:00:00`);
  if (Number.isNaN(parsed.getTime())) return date;
  return new Intl.DateTimeFormat(locale === "zh" ? "zh-CN" : "en-US", {
    year: "numeric",
    month: locale === "zh" ? "2-digit" : "short",
    day: "2-digit",
  }).format(parsed);
}

function categoryLabel(category: CategoryId, locale: Locale) {
  const labels: Record<CategoryId, [string, string]> = {
    movie: ["电影", "Movie"],
    travel: ["旅行", "Travel"],
    exhibition: ["展览", "Exhibition"],
    food: ["餐饮", "Food"],
    shopping: ["购物", "Shopping"],
    other: ["其他", "Other"],
  };
  return labels[category][locale === "zh" ? 0 : 1];
}

function movieFormatLabel(format: string) {
  return { imax: "IMAX", "dolby-cinema": "Dolby Cinema", cinity: "CINITY", "4dx": "4DX" }[format] ?? format;
}

function cabinLabel(cabin: string, locale: Locale) {
  const labels: Record<string, [string, string]> = {
    economy: ["经济舱", "Economy"],
    premium: ["超级经济舱", "Premium Economy"],
    business: ["公务舱", "Business"],
    first: ["头等舱", "First"],
  };
  return (labels[cabin] ?? [cabin, cabin])[locale === "zh" ? 0 : 1];
}

function trainClassLabel(value: string, locale: Locale) {
  const labels: Record<string, [string, string]> = {
    second: ["二等座", "Second class"],
    first: ["一等座", "First class"],
    business: ["商务座", "Business class"],
    sleeper: ["卧铺", "Sleeper"],
  };
  return (labels[value] ?? [value, value])[locale === "zh" ? 0 : 1];
}

function tagLabel(tag: string, locale: Locale) {
  const systemTag = suggestedTags.find((item) => item.id === tag);
  if (systemTag) return locale === "zh" ? systemTag.zh : systemTag.en;
  return tag.startsWith("custom:") ? tag.slice("custom:".length) : tag;
}

function recordTitle(record: StubRecord, locale: Locale) {
  return locale === "en" && record.titleEn ? record.titleEn : record.title;
}

function recordNote(record: StubRecord, locale: Locale) {
  return locale === "en" && record.noteEn ? record.noteEn : record.note;
}

function tripTitle(trip: TripBook, locale: Locale) {
  return locale === "en" && trip.titleEn ? trip.titleEn : trip.title;
}

function ScreenHeader({ title, onBack, action }: { title: string; onBack: () => void; action?: React.ReactNode }) {
  return (
    <header className="subpage-header">
      <button className="icon-button plain" type="button" onClick={onBack} aria-label="Back">
        <ChevronLeftIcon width={23} height={23} />
      </button>
      <h1>{title}</h1>
      <span className="header-action">{action}</span>
    </header>
  );
}

function FlightCard({ details, locale }: { details: FlightDetails; locale: Locale }) {
  const airlineMark = (details.airlineCode || details.airline || "FL").slice(0, 2).toUpperCase();
  const airlineLogo = airlineLogoFor(details.airlineCode);
  return (
    <section className="flight-card" aria-label={locale === "zh" ? "航班卡片" : "Flight card"}>
      <div className="flight-card-top">
        {airlineLogo ? <img className="airline-logo" src={airlineLogo} alt={`${details.airline || airlineMark} logo`} draggable={false} /> : <span className="airline-mark" aria-label={`${details.airline} airline code`}>{airlineMark}</span>}
        <div>
          <p>{details.airline || (locale === "zh" ? "航空公司" : "Airline")}</p>
          <strong>{details.flightNumber || "FL 000"}</strong>
        </div>
        <span className="flight-status">{locale === "zh" ? "行程存根" : "TRIP STUB"}</span>
      </div>
      <div className="flight-route">
        <div>
          <strong>{details.departure || "SHA"}</strong>
          <span>{details.departureTime || "08:25"}</span>
        </div>
        <div className="flight-line" aria-hidden="true">
          <PaperPlaneIcon width={20} height={20} />
        </div>
        <div>
          <strong>{details.arrival || "CTS"}</strong>
          <span>{details.arrivalTime || "13:05"}</span>
        </div>
      </div>
      <div className="flight-meta">
        <span><small>{locale === "zh" ? "机型" : "AIRCRAFT"}</small>{details.aircraft || "A320neo"}</span>
        <span><small>{locale === "zh" ? "舱位" : "CABIN"}</small>{cabinLabel(details.cabin, locale)}</span>
        <span><small>{locale === "zh" ? "座位" : "SEAT"}</small>{details.seat || "12A"}</span>
      </div>
      <p className="flight-disclaimer">{locale === "zh" ? "基于你填写的信息生成 · 非实时航班状态" : "Generated from your details · Not live flight status"}</p>
    </section>
  );
}

function BottomNav({
  active,
  locale,
  onNavigate,
  onAdd,
}: {
  active: MainTab;
  locale: Locale;
  onNavigate: (tab: MainTab) => void;
  onAdd: () => void;
}) {
  const items: Array<{ id: MainTab; zh: string; en: string; icon: React.ReactNode }> = [
    { id: "home", zh: "存根", en: "Stubs", icon: <HomeIcon /> },
    { id: "trips", zh: "旅册", en: "Trips", icon: <ReaderIcon /> },
    { id: "wall", zh: "墙", en: "Wall", icon: <DashboardIcon /> },
    { id: "profile", zh: "我的", en: "Me", icon: <PersonIcon /> },
  ];
  return (
    <nav className="bottom-nav" aria-label={locale === "zh" ? "主导航" : "Main navigation"}>
      {items.slice(0, 2).map((item) => (
        <button key={item.id} type="button" className={active === item.id ? "nav-item active" : "nav-item"} onClick={() => onNavigate(item.id)}>
          {item.icon}<span>{locale === "zh" ? item.zh : item.en}</span>
        </button>
      ))}
      <button className="nav-add" type="button" onClick={onAdd} aria-label={locale === "zh" ? "留下一张" : "Add a stub"}>
        <PlusIcon width={25} height={25} />
      </button>
      {items.slice(2).map((item) => (
        <button key={item.id} type="button" className={active === item.id ? "nav-item active" : "nav-item"} onClick={() => onNavigate(item.id)}>
          {item.icon}<span>{locale === "zh" ? item.zh : item.en}</span>
        </button>
      ))}
    </nav>
  );
}

export default function Prototype() {
  const keyboard = useKeyboard();
  const cameraInput = useRef<HTMLInputElement | null>(null);
  const libraryInput = useRef<HTMLInputElement | null>(null);
  const attachmentInput = useRef<HTMLInputElement | null>(null);
  const posterInput = useRef<HTMLInputElement | null>(null);
  const [page, setPage] = useState<Page>("home");
  const [activeTab, setActiveTab] = useState<MainTab>("home");
  const [returnTab, setReturnTab] = useState<MainTab>("home");
  const [db, setDb] = useState<IDBDatabase | null>(null);
  const [userRecords, setUserRecords] = useState<StubRecord[]>([]);
  const [userMedia, setUserMedia] = useState<MediaAsset[]>([]);
  const [userTrips, setUserTrips] = useState<TripBook[]>([]);
  const [userTripItems, setUserTripItems] = useState<TripItem[]>([]);
  const [mediaUrls, setMediaUrls] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [storageError, setStorageError] = useState(false);
  const [draft, setDraft] = useState<DraftStub>(makeEmptyDraft);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [selectedTripId, setSelectedTripId] = useState(seedTrip.id);
  const [filterOpen, setFilterOpen] = useState(false);
  const [filter, setFilter] = useState<CategoryId | "all">("all");
  const [tagFilter, setTagFilter] = useState<string | "all">("all");
  const [wallFilter, setWallFilter] = useState<CategoryId | "all">("all");
  const [wallTagFilter, setWallTagFilter] = useState<string | "all">("all");
  const [tripMode, setTripMode] = useState<"map" | "books">("map");
  const [tripPickerOpen, setTripPickerOpen] = useState(false);
  const [tripCreateOpen, setTripCreateOpen] = useState(false);
  const [plusOpen, setPlusOpen] = useState(false);
  const [newTrip, setNewTrip] = useState({ title: "", startDate: getLocalDate(), endDate: getLocalDate(), route: "", note: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [locale, setLocale] = useState<Locale>(() => (window.localStorage.getItem(LOCALE_KEY) === "en" ? "en" : "zh"));
  const [theme, setTheme] = useState<ThemeSetting>(() => {
    const stored = window.localStorage.getItem(THEME_KEY);
    return stored === "light" || stored === "dark" ? stored : "system";
  });
  const [systemDark, setSystemDark] = useState(() => window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false);

  const allRecords = useMemo(() => {
    const records = new Map(seedRecords.map((record) => [record.id, record]));
    userRecords.forEach((record) => records.set(record.id, record));
    return [...records.values()].sort((a, b) => b.occurredOn.localeCompare(a.occurredOn));
  }, [userRecords]);
  const allTrips = useMemo(() => [seedTrip, ...userTrips.filter((trip) => trip.id !== seedTrip.id)], [userTrips]);
  const allTripItems = useMemo(() => {
    const items = new Map(seedTripItems.map((item) => [item.id, item]));
    userTripItems.forEach((item) => items.set(item.id, item));
    return [...items.values()];
  }, [userTripItems]);
  const availableTags = useMemo(() => [...new Set(allRecords.flatMap((record) => record.tags))], [allRecords]);
  const visibleRecords = useMemo(
    () => allRecords.filter((record) => (filter === "all" || record.category === filter) && (tagFilter === "all" || record.tags.includes(tagFilter))),
    [allRecords, filter, tagFilter],
  );
  const wallRecords = useMemo(
    () => allRecords.filter((record) => (wallFilter === "all" || record.category === wallFilter) && (wallTagFilter === "all" || record.tags.includes(wallTagFilter))),
    [allRecords, wallFilter, wallTagFilter],
  );
  const selectedRecord = allRecords.find((record) => record.id === selectedId) ?? null;
  const selectedTrip = allTrips.find((trip) => trip.id === selectedTripId) ?? seedTrip;
  const selectedTripRecords = useMemo(
    () => allTripItems
      .filter((item) => item.tripId === selectedTrip.id)
      .sort((a, b) => a.order - b.order)
      .map((item) => ({ item, record: allRecords.find((record) => record.id === item.stubId) }))
      .filter((value): value is { item: TripItem; record: StubRecord } => Boolean(value.record)),
    [allTripItems, allRecords, selectedTrip.id],
  );
  const resolvedTheme = theme === "system" ? (systemDark ? "dark" : "light") : theme;
  const txt = (zh: string, en: string) => (locale === "zh" ? zh : en);
  const posterCandidate = posterCandidateFor(draft.title);

  useEffect(() => {
    let cancelled = false;
    void loadLibrary()
      .then((library) => {
        if (cancelled) {
          library.db.close();
          return;
        }
        setDb(library.db);
        setUserRecords(library.records);
        setUserMedia(library.media);
        setUserTrips(library.trips);
        setUserTripItems(library.tripItems);
        if (library.migrated > 0) setToast(txt(`已安全迁移 ${library.migrated} 张旧存根`, `${library.migrated} saved stubs migrated safely`));
      })
      .catch(() => setStorageError(true))
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // Database initialization runs once so it cannot overwrite migrated media.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const urls: Record<string, string> = {};
    const created: string[] = [];
    seedMedia.forEach((asset) => {
      if (asset.url) urls[asset.id] = asset.url;
    });
    userMedia.forEach((asset) => {
      if (asset.url) urls[asset.id] = asset.url;
      if (asset.blob) {
        const objectUrl = URL.createObjectURL(asset.blob);
        urls[asset.id] = objectUrl;
        created.push(objectUrl);
      }
    });
    setMediaUrls(urls);
    return () => created.forEach((url) => URL.revokeObjectURL(url));
  }, [userMedia]);

  useEffect(() => {
    const query = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = (event: MediaQueryListEvent) => setSystemDark(event.matches);
    query.addEventListener?.("change", onChange);
    return () => query.removeEventListener?.("change", onChange);
  }, []);

  useEffect(() => {
    window.localStorage.setItem(THEME_KEY, theme);
  }, [theme]);

  useEffect(() => {
    window.localStorage.setItem(LOCALE_KEY, locale);
    document.documentElement.lang = locale === "zh" ? "zh-CN" : "en";
  }, [locale]);

  useEffect(() => {
    document.documentElement.dataset.stubTheme = resolvedTheme;
    document.documentElement.style.colorScheme = resolvedTheme;
  }, [resolvedTheme]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    if (page !== "review") keyboard.hide();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  const mediaUrl = (id?: string) => (id ? mediaUrls[id] : undefined);

  const navigateMain = (tab: MainTab) => {
    keyboard.hide();
    setActiveTab(tab);
    setPage(tab);
    setError("");
  };

  const navigate = (next: Page) => {
    keyboard.hide();
    setError("");
    setPage(next);
  };

  const openDetail = (id: string, from: MainTab = activeTab) => {
    setSelectedId(id);
    setReturnTab(from);
    navigate("detail");
  };

  const startEditing = (record: StubRecord) => {
    if (record.source !== "user") return;
    const toPending = (id: string, role: MediaRole): PendingMedia | null => {
      const asset = userMedia.find((item) => item.id === id);
      const preview = mediaUrl(id);
      if (!asset?.blob || !preview) return null;
      return {
        id: asset.id,
        role,
        blob: asset.blob,
        preview,
        name: asset.name ?? `${record.title}.jpg`,
        ownsPreview: false,
      };
    };
    const primary = toPending(record.primaryMediaId, "ticket");
    if (!primary) {
      setToast(txt("原票据图片还没有准备好", "The original ticket image is not ready yet"));
      return;
    }
    const base = makeEmptyDraft();
    const poster = record.posterMediaId && record.posterMediaId !== "media-seed-movie-poster"
      ? toPending(record.posterMediaId, "poster")
      : null;
    const attachments = record.attachmentIds
      .map((id) => toPending(id, "memory-photo"))
      .filter((asset): asset is PendingMedia => Boolean(asset));
    const existingTrip = allTripItems.find((item) => item.stubId === record.id)?.tripId ?? "";
    const next: DraftStub = {
      ...base,
      editingId: record.id,
      originalAttachmentIds: [...record.attachmentIds],
      originalPosterMediaId: record.posterMediaId,
      title: record.title,
      date: record.occurredOn,
      category: record.category,
      subtype: record.subtype ?? "unknown",
      note: record.note,
      tags: [...record.tags],
      primary,
      attachments,
      poster,
      useSuggestedPoster: record.posterMediaId === "media-seed-movie-poster",
      tripId: existingTrip,
    };
    if (record.details.kind === "movie") {
      next.movieFormats = [...record.details.formatIds];
      next.movieCinema = record.details.cinema;
      next.movieHall = record.details.hall;
      next.movieSeat = record.details.seat;
    } else if (record.details.kind === "flight") {
      next.airline = record.details.airline;
      next.airlineCode = record.details.airlineCode;
      next.flightNumber = record.details.flightNumber;
      next.aircraft = record.details.aircraft;
      next.cabin = record.details.cabin;
      next.flightSeat = record.details.seat;
      next.departure = record.details.departure;
      next.arrival = record.details.arrival;
      next.departureTime = record.details.departureTime;
      next.arrivalTime = record.details.arrivalTime;
    } else if (record.details.kind === "train") {
      next.trainOperator = record.details.operator;
      next.trainNumber = record.details.trainNumber;
      next.trainClass = record.details.seatClass;
      next.trainCoach = record.details.coach;
      next.trainSeat = record.details.seat;
      next.departure = record.details.departure;
      next.arrival = record.details.arrival;
      next.departureTime = record.details.departureTime;
    } else {
      next.location = record.details.location;
    }
    setDraft(next);
    setSelectedId(record.id);
    navigate("review");
  };

  const cancelDraft = () => {
    [draft.primary, ...draft.attachments, ...(draft.poster ? [draft.poster] : [])]
      .filter((asset): asset is PendingMedia => Boolean(asset?.ownsPreview))
      .forEach((asset) => URL.revokeObjectURL(asset.preview));
    const wasEditing = Boolean(draft.editingId);
    setDraft(makeEmptyDraft());
    navigate(wasEditing ? "detail" : "import");
  };

  const handlePrimaryFile = async (file?: File) => {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      setError(txt("请选择图片格式的票据", "Please choose an image file"));
      return;
    }
    setBusy(true);
    setError("");
    try {
      const primary = await readAndResizeImage(file, "ticket");
      setDraft({ ...makeEmptyDraft(), primary, title: file.name.replace(/\.[^.]+$/, "") });
      navigate("review");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : txt("这张图片暂时无法读取", "This image could not be read"));
    } finally {
      setBusy(false);
      if (cameraInput.current) cameraInput.current.value = "";
      if (libraryInput.current) libraryInput.current.value = "";
    }
  };

  const handleAttachments = async (files?: FileList | null) => {
    if (!files?.length) return;
    setBusy(true);
    setError("");
    try {
      const selected = [...files].filter((file) => file.type.startsWith("image/")).slice(0, 6 - draft.attachments.length);
      const assets = await Promise.all(selected.map((file) => readAndResizeImage(file, "memory-photo")));
      setDraft((current) => ({ ...current, attachments: [...current.attachments, ...assets] }));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : txt("照片暂时无法读取", "Photos could not be read"));
    } finally {
      setBusy(false);
      if (attachmentInput.current) attachmentInput.current.value = "";
    }
  };

  const handlePosterFile = async (file?: File) => {
    if (!file) return;
    setBusy(true);
    try {
      const poster = await readAndResizeImage(file, "poster");
      setDraft((current) => {
        if (current.poster?.ownsPreview) URL.revokeObjectURL(current.poster.preview);
        return { ...current, poster, useSuggestedPoster: false };
      });
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : txt("海报暂时无法读取", "Poster could not be read"));
    } finally {
      setBusy(false);
      if (posterInput.current) posterInput.current.value = "";
    }
  };

  const toggleSuggestedPoster = () => {
    if (!posterCandidate) return;
    setDraft((current) => {
      if (current.poster?.ownsPreview) URL.revokeObjectURL(current.poster.preview);
      return { ...current, poster: null, useSuggestedPoster: current.poster ? true : !current.useSuggestedPoster };
    });
  };

  const toggleDraftTag = (tag: string) => {
    setDraft((current) => ({
      ...current,
      tags: current.tags.includes(tag) ? current.tags.filter((value) => value !== tag) : [...current.tags, tag],
    }));
  };

  const addCustomTag = () => {
    const tag = draft.tagInput.trim();
    const storedTag = `custom:${tag}`;
    if (!tag || draft.tags.includes(storedTag)) return;
    setDraft((current) => ({ ...current, tags: [...current.tags, storedTag], tagInput: "" }));
  };

  const buildDetails = (): StubDetails => {
    if (draft.category === "movie") {
      return {
        kind: "movie",
        filmTitle: draft.title,
        cinema: draft.movieCinema,
        hall: draft.movieHall,
        seat: draft.movieSeat,
        formatIds: draft.movieFormats,
      };
    }
    if (draft.category === "travel" && draft.subtype === "flight") {
      return {
        kind: "flight",
        airline: draft.airline,
        airlineCode: draft.airlineCode.toUpperCase(),
        flightNumber: draft.flightNumber.toUpperCase(),
        aircraft: draft.aircraft,
        cabin: draft.cabin,
        seat: draft.flightSeat.toUpperCase(),
        departure: draft.departure.toUpperCase(),
        arrival: draft.arrival.toUpperCase(),
        departureTime: draft.departureTime,
        arrivalTime: draft.arrivalTime,
      };
    }
    if (draft.category === "travel" && draft.subtype === "train") {
      return {
        kind: "train",
        operator: draft.trainOperator,
        trainNumber: draft.trainNumber.toUpperCase(),
        seatClass: draft.trainClass,
        coach: draft.trainCoach,
        seat: draft.trainSeat,
        departure: draft.departure,
        arrival: draft.arrival,
        departureTime: draft.departureTime,
      };
    }
    return { kind: "generic", location: draft.location };
  };

  const saveDraft = async () => {
    if (!draft.title.trim()) {
      setError(txt("给这张存根起一个名字吧", "Give this stub a title"));
      return;
    }
    if (!draft.primary) {
      setError(txt("先放入一张票据图片", "Add a ticket image first"));
      return;
    }
    if (!db) {
      setError(txt("本地资料库尚未准备好", "The local library is not ready"));
      return;
    }
    setBusy(true);
    setError("");
    const timestamp = new Date().toISOString();
    const existingRecord = draft.editingId ? userRecords.find((item) => item.id === draft.editingId) : undefined;
    const posterMediaId = draft.poster?.id ?? (draft.category === "movie" && draft.useSuggestedPoster && posterCandidate ? posterCandidate.mediaId : undefined);
    const record: StubRecord = {
      schemaVersion: 2,
      id: existingRecord?.id ?? `stub-${Date.now()}`,
      source: "user",
      title: draft.title.trim(),
      occurredOn: draft.date,
      category: draft.category,
      subtype: draft.category === "travel" ? draft.subtype : undefined,
      note: draft.note.trim(),
      tags: draft.tags,
      primaryMediaId: draft.primary.id,
      attachmentIds: draft.attachments.map((asset) => asset.id),
      posterMediaId,
      details: buildDetails(),
      createdAt: existingRecord?.createdAt ?? timestamp,
      updatedAt: timestamp,
    };
    const media = [draft.primary, ...draft.attachments, ...(draft.poster ? [draft.poster] : [])].map<MediaAsset>((asset) => ({
      id: asset.id,
      role: asset.role,
      source: "upload",
      blob: asset.blob,
      name: asset.name,
      createdAt: timestamp,
    }));
    const nextMediaIds = new Set([record.primaryMediaId, ...record.attachmentIds, ...(record.posterMediaId ? [record.posterMediaId] : [])]);
    const removedMediaIds = [...draft.originalAttachmentIds, ...(draft.originalPosterMediaId ? [draft.originalPosterMediaId] : [])]
      .filter((id) => id !== "media-seed-movie-poster" && !nextMediaIds.has(id));
    const existingTripCount = allTripItems.filter((item) => item.tripId === draft.tripId).length;
    const currentRecordTripItems = allTripItems.filter((item) => item.stubId === record.id);
    const matchingTripItem = currentRecordTripItems.find((item) => item.tripId === draft.tripId);
    const tripItem = draft.tripId && !matchingTripItem ? {
      id: `trip-item-${draft.tripId}-${record.id}`,
      tripId: draft.tripId,
      stubId: record.id,
      order: existingTripCount + 1,
      day: 1,
      caption: "",
      rotation: 0,
      scale: 1,
    } satisfies TripItem : undefined;
    const removedTripItemIds = currentRecordTripItems.filter((item) => item.tripId !== draft.tripId).map((item) => item.id);
    try {
      await saveRecordBundle(db, record, media, tripItem, removedMediaIds, removedTripItemIds);
      setUserRecords((current) => [record, ...current.filter((item) => item.id !== record.id)]);
      setUserMedia((current) => [...media, ...current.filter((item) => !removedMediaIds.includes(item.id) && !media.some((asset) => asset.id === item.id))]);
      setUserTripItems((current) => {
        const kept = current.filter((item) => !removedTripItemIds.includes(item.id) && item.id !== tripItem?.id);
        return tripItem ? [...kept, tripItem] : kept;
      });
      [draft.primary, ...draft.attachments, ...(draft.poster ? [draft.poster] : [])]
        .filter((asset) => asset.ownsPreview)
        .forEach((asset) => URL.revokeObjectURL(asset.preview));
      setDraft(makeEmptyDraft());
      setFilter("all");
      setTagFilter("all");
      if (existingRecord) {
        setSelectedId(record.id);
        navigate("detail");
        setToast(txt("这张存根已经更新", "Stub updated"));
      } else {
        navigateMain("home");
        setToast(txt("已为这一天留存根", "Stub saved to this day"));
      }
    } catch {
      setError(txt("保存没有完成，请再试一次", "Save did not finish. Please try again"));
    } finally {
      setBusy(false);
    }
  };

  const addSelectedToTrip = async (tripId: string) => {
    if (!selectedRecord || !db) return;
    const existing = allTripItems.find((item) => item.tripId === tripId && item.stubId === selectedRecord.id);
    if (existing) {
      setTripPickerOpen(false);
      setToast(txt("这张已经在旅册里了", "This stub is already in the trip book"));
      return;
    }
    const item: TripItem = {
      id: `trip-item-${tripId}-${selectedRecord.id}`,
      tripId,
      stubId: selectedRecord.id,
      order: allTripItems.filter((value) => value.tripId === tripId).length + 1,
      day: 1,
      caption: "",
      rotation: 0,
      scale: 1,
    };
    try {
      await saveTripItem(db, item);
      setUserTripItems((current) => [...current, item]);
      setTripPickerOpen(false);
      setToast(txt("已收进旅册，原存根仍在首页", "Added to the trip book; the original stays on Home"));
    } catch {
      setToast(txt("暂时没有收进去", "Could not add it yet"));
    }
  };

  const createTrip = async () => {
    if (!newTrip.title.trim() || !db) return;
    const trip: TripBook = {
      id: `trip-${Date.now()}`,
      source: "user",
      title: newTrip.title.trim(),
      startDate: newTrip.startDate,
      endDate: newTrip.endDate,
      route: newTrip.route.trim(),
      note: newTrip.note.trim(),
    };
    try {
      await saveTripBook(db, trip);
      setUserTrips((current) => [trip, ...current]);
      setSelectedTripId(trip.id);
      setNewTrip({ title: "", startDate: getLocalDate(), endDate: getLocalDate(), route: "", note: "" });
      setTripCreateOpen(false);
      setTripMode("books");
      setToast(txt("新旅册已经放上书架", "Your new trip book is on the shelf"));
    } catch {
      setToast(txt("旅册暂时没有保存", "The trip book could not be saved"));
    }
  };

  const removeSelected = async () => {
    if (!selectedRecord || selectedRecord.source !== "user" || !db) return;
    try {
      await deleteRecordBundle(db, selectedRecord);
      setUserRecords((current) => current.filter((record) => record.id !== selectedRecord.id));
      setUserMedia((current) => current.filter((asset) => ![selectedRecord.primaryMediaId, selectedRecord.posterMediaId, ...selectedRecord.attachmentIds].includes(asset.id)));
      setUserTripItems((current) => current.filter((item) => item.stubId !== selectedRecord.id));
      setSelectedId(null);
      navigateMain(returnTab);
      setToast(txt("这张存根已移除，旧版底稿仍保留", "Stub removed; the legacy fallback remains untouched"));
    } catch {
      setToast(txt("暂时无法移除", "Could not remove it yet"));
    }
  };

  const exportArchive = () => {
    const payload = {
      exportedAt: new Date().toISOString(),
      schemaVersion: 2,
      records: userRecords,
      trips: userTrips,
      tripItems: userTripItems,
      note: "Media blobs remain in the local IndexedDB demo.",
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `stub-archive-${getLocalDate()}.json`;
    anchor.click();
    URL.revokeObjectURL(url);
    setToast(txt("资料索引已导出", "Archive index exported"));
  };

  const renderBrandHeader = (showFilter = true) => (
    <header className="brand-header">
      <div>
        <p className="brand-name">Stub</p>
        <p className="brand-cn">{txt("生活存根", "LIFE ARCHIVE")}</p>
      </div>
      <div className="header-tools">
        <button className="mini-language" type="button" onClick={() => setLocale((value) => (value === "zh" ? "en" : "zh"))} aria-label={txt("切换英文", "Switch to Chinese")} aria-pressed={locale === "en"}>
          {locale === "zh" ? "EN" : "中"}
        </button>
        {showFilter ? (
          <button className="icon-button filter-button" type="button" onClick={() => setFilterOpen(true)} aria-label={txt("筛选存根", "Filter stubs")} data-testid="filter-button">
            <ListBulletIcon width={22} height={22} />
          </button>
        ) : null}
      </div>
    </header>
  );

  const wallCoverId = (record: StubRecord) => record.posterMediaId || record.attachmentIds[0] || record.primaryMediaId;
  const themeOptions: Array<{ id: ThemeSetting; zh: string; en: string; icon: React.ReactNode }> = [
    { id: "system", zh: "跟随系统", en: "System", icon: <MixerHorizontalIcon /> },
    { id: "light", zh: "浅色", en: "Light", icon: <SunIcon /> },
    { id: "dark", zh: "深色", en: "Dark", icon: <MoonIcon /> },
  ];

  return (
    <div className="stub-app" data-theme={resolvedTheme} lang={locale === "zh" ? "zh-CN" : "en"}>
      {page === "home" ? (
        <>
          <MobileScroll key="home" className="app-screen stub-scroll">
            <main className="stub-home" data-testid="home-screen">
              {renderBrandHeader(true)}
              <section className="month-intro" aria-labelledby="month-title">
                <p className="month-eyebrow">AUGUST · 2026</p>
                <h1 className="month-title" id="month-title">{txt("八月", "August")}</h1>
                <p className="month-caption">{txt("记录生活，留住每个瞬间。", "Keep the small proofs that life happened.")}</p>
                {filter !== "all" || tagFilter !== "all" ? <p className="filter-label">{txt("正在查看", "Viewing")}: {[filter !== "all" ? categoryLabel(filter, locale) : "", tagFilter !== "all" ? tagLabel(tagFilter, locale) : ""].filter(Boolean).join(" · ")}</p> : null}
              </section>

              {loading ? (
                <section className="loading-paper"><span />{txt("正在打开你的存根盒…", "Opening your stub box…")}</section>
              ) : visibleRecords.length ? (
                <section className="stub-timeline" aria-label={txt("我的存根", "My stubs")}>
                  {visibleRecords.map((record, index) => (
                    <article className={index === 0 ? "stub-entry featured-entry" : "stub-entry compact-entry"} key={record.id}>
                      <button className="ticket-button" type="button" onClick={() => openDetail(record.id, "home")} aria-label={`${txt("查看", "View")} ${recordTitle(record, locale)}`}>
                        <img className="ticket-image" src={mediaUrl(record.primaryMediaId)} alt={recordTitle(record, locale)} draggable={false} />
                      </button>
                      {index === 0 ? (
                        <div className="memory-note">
                          <p>{recordNote(record, locale) || txt("这一张，也替你记住了那一天。", "This one remembers the day for you.")}</p>
                          <time dateTime={record.occurredOn}>— {formatDate(record.occurredOn, locale)}</time>
                          <div className="inline-tags">
                            {record.details.kind === "movie" ? record.details.formatIds.map((format) => <span key={format}>{movieFormatLabel(format)}</span>) : null}
                            {record.tags.slice(0, 2).map((tag) => <span key={tag}>{tagLabel(tag, locale)}</span>)}
                          </div>
                        </div>
                      ) : (
                        <button className="compact-caption" type="button" onClick={() => openDetail(record.id, "home")}>
                          <span>{categoryLabel(record.category, locale)}</span>
                          <strong>{recordTitle(record, locale)}</strong>
                          <ChevronRightIcon />
                        </button>
                      )}
                    </article>
                  ))}
                </section>
              ) : (
                <section className="empty-state"><p>{txt("这里还没有符合筛选的存根。", "No stubs match these filters yet.")}</p><button type="button" onClick={() => { setFilter("all"); setTagFilter("all"); }}>{txt("查看全部", "View all")}</button></section>
              )}
              {storageError ? <p className="storage-warning">{txt("本地资料库没有打开；请保留当前页面并稍后重试。", "The local library did not open. Keep this page and try again later.")}</p> : null}
            </main>
          </MobileScroll>
          <BottomNav active="home" locale={locale} onNavigate={navigateMain} onAdd={() => navigate("import")} />
        </>
      ) : null}

      {page === "trips" ? (
        <>
          <MobileScroll key="trips" className="app-screen stub-scroll">
            <main className="trip-home" data-testid="trips-screen">
              {renderBrandHeader(false)}
              <section className="trip-intro">
                <p className="section-eyebrow">TRIP BOOKS</p>
                <div className="section-title-row">
                  <div><h1>{txt("旅册", "Journeys")}</h1><p>{txt("同一张存根，只保存一次，在旅册里重新排版。", "One stub, saved once and arranged into a journey.")}</p></div>
                  <button className="icon-button small" type="button" onClick={() => setTripCreateOpen(true)} aria-label={txt("新建旅册", "New trip book")}><PlusIcon /></button>
                </div>
              </section>
              <div className="segmented-control" role="tablist">
                <button type="button" role="tab" aria-selected={tripMode === "map"} className={tripMode === "map" ? "selected" : ""} onClick={() => setTripMode("map")}>{txt("地图", "Map")}</button>
                <button type="button" role="tab" aria-selected={tripMode === "books"} className={tripMode === "books" ? "selected" : ""} onClick={() => setTripMode("books")}>{txt("书架", "Books")}</button>
              </div>

              {tripMode === "map" ? (
                <section className="map-experience">
                  <div className="map-canvas">
                    <img src="/stub-assets/trip-map-hokkaido.png" alt={txt("北海道旅行路线地图", "Hokkaido journey map")} draggable={false} />
                    <button className="map-label map-label-otaru" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>{txt("小樽", "Otaru")}</button>
                    <button className="map-label map-label-sapporo active" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>{txt("札幌", "Sapporo")}</button>
                    <button className="map-label map-label-asahikawa" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>{txt("旭川", "Asahikawa")}</button>
                    <button className="map-label map-label-chitose" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>{txt("新千岁", "CTS")}</button>
                    <button className="map-chapter-card" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>
                      <span><DrawingPinIcon />{txt("札幌 · 第 4 日", "Sapporo · Day 4")}</span>
                      <strong>{txt("雨停以后，沿着狸小路慢慢走。", "After the rain, we wandered through Tanukikoji.")}</strong>
                      <small><ArchiveIcon /> {selectedTripRecords.length} {txt("枚存根", "stubs")}</small>
                    </button>
                  </div>
                  <button className="trip-cover-card" type="button" onClick={() => { setSelectedTripId(seedTrip.id); navigate("tripBook"); }}>
                    <img src="/stub-assets/trip-map-hokkaido.png" alt="" draggable={false} />
                    <span className="trip-cover-copy">
                      <small>HOKKAIDO · SUMMER 2026</small>
                      <strong>{tripTitle(seedTrip, locale)}</strong>
                      <em>{locale === "en" && seedTrip.routeEn ? seedTrip.routeEn : seedTrip.route} · 8 {txt("天", "days")} · {selectedTripRecords.length} {txt("枚存根", "stubs")}</em>
                      <b>{txt("打开旅册", "Open book")}<ChevronRightIcon /></b>
                    </span>
                  </button>
                </section>
              ) : (
                <section className="book-shelf">
                  {allTrips.map((trip) => {
                    const count = allTripItems.filter((item) => item.tripId === trip.id).length;
                    return (
                      <button className="shelf-book" type="button" key={trip.id} onClick={() => { setSelectedTripId(trip.id); navigate("tripBook"); }}>
                        <span className="book-spine">STUB · {new Date(trip.startDate).getFullYear()}</span>
                        <span className="book-copy"><small>{formatDate(trip.startDate, locale)}—{formatDate(trip.endDate, locale)}</small><strong>{tripTitle(trip, locale)}</strong><em>{(locale === "en" && trip.routeEn ? trip.routeEn : trip.route) || txt("等待一条路线", "A route waiting to happen")}</em><b>{count} {txt("枚", "stubs")}</b></span>
                        <ChevronRightIcon />
                      </button>
                    );
                  })}
                  <button className="new-book-card" type="button" onClick={() => setTripCreateOpen(true)}><CardStackPlusIcon />{txt("新建一本旅册", "Create a trip book")}</button>
                </section>
              )}
            </main>
          </MobileScroll>
          <BottomNav active="trips" locale={locale} onNavigate={navigateMain} onAdd={() => navigate("import")} />
        </>
      ) : null}

      {page === "wall" ? (
        <>
          <MobileScroll key="wall" className="app-screen stub-scroll">
            <main className="wall-page" data-testid="wall-screen">
              {renderBrandHeader(false)}
              <section className="wall-intro"><p className="section-eyebrow">THE STUB WALL</p><h1>{txt("存根墙", "The Wall")}</h1><p>{txt("海报、照片与票根，拼成生活的全景。", "Posters, photos and tickets — your life at a glance.")}</p></section>
              <Carousel ariaLabel={txt("存根墙筛选", "Wall filters")} className="wall-filter-carousel" contentClassName="wall-filter-track">
                {["all", ...categoryIds].map((value) => (
                  <button key={value} type="button" className={wallFilter === value ? "wall-filter selected" : "wall-filter"} onClick={() => setWallFilter(value as CategoryId | "all")}>
                    {value === "all" ? txt("全部", "All") : categoryLabel(value as CategoryId, locale)}
                  </button>
                ))}
              </Carousel>
              {availableTags.length ? <><p className="wall-filter-label">{txt("按标签", "BY TAG")}</p><Carousel ariaLabel={txt("按标签筛选存根墙", "Filter Wall by tag")} className="wall-filter-carousel wall-tag-carousel" contentClassName="wall-filter-track"><button type="button" className={wallTagFilter === "all" ? "wall-filter selected" : "wall-filter"} onClick={() => setWallTagFilter("all")}>{txt("全部标签", "All tags")}</button>{availableTags.map((tag) => <button key={tag} type="button" className={wallTagFilter === tag ? "wall-filter selected" : "wall-filter"} onClick={() => setWallTagFilter(tag)}>{tagLabel(tag, locale)}</button>)}</Carousel></> : null}
              <section className="stub-wall" aria-label={txt("所有存根", "All stubs")}>
                {wallRecords.map((record, index) => (
                  <button className={`wall-tile wall-${record.category} wall-tile-${index % 3}`} type="button" key={record.id} onClick={() => openDetail(record.id, "wall")}>
                    <img src={mediaUrl(wallCoverId(record))} alt={recordTitle(record, locale)} draggable={false} />
                    <span className="wall-tile-copy"><small>{categoryLabel(record.category, locale)} · {formatDate(record.occurredOn, locale)}</small><strong>{recordTitle(record, locale)}</strong></span>
                  </button>
                ))}
              </section>
            </main>
          </MobileScroll>
          <BottomNav active="wall" locale={locale} onNavigate={navigateMain} onAdd={() => navigate("import")} />
        </>
      ) : null}

      {page === "profile" ? (
        <>
          <MobileScroll key="profile" className="app-screen stub-scroll">
            <main className="profile-page" data-testid="profile-screen">
              {renderBrandHeader(false)}
              <section className="profile-intro"><p className="section-eyebrow">YOUR ARCHIVE</p><h1>{txt("我的存根盒", "My Stub Box")}</h1><p>{txt("只属于你的本地生活档案。", "A private, local archive of your life.")}</p></section>
              <section className="stats-card">
                <span><strong>{allRecords.length}</strong><small>{txt("枚存根", "stubs")}</small></span>
                <span><strong>{allTrips.length}</strong><small>{txt("本旅册", "trip books")}</small></span>
                <span><strong>{new Set(allRecords.flatMap((record) => record.tags)).size}</strong><small>{txt("个标签", "tags")}</small></span>
              </section>
              <section className="settings-section">
                <h2>{txt("外观", "Appearance")}</h2>
                <div className="theme-grid">
                  {themeOptions.map((option) => (
                    <button key={option.id} type="button" aria-pressed={theme === option.id} className={theme === option.id ? "theme-option selected" : "theme-option"} onClick={() => setTheme(option.id)}>
                      {option.icon}<span>{locale === "zh" ? option.zh : option.en}</span>{theme === option.id ? <CheckCircledIcon /> : null}
                    </button>
                  ))}
                </div>
                <button className="settings-row" type="button" aria-pressed={locale === "en"} onClick={() => setLocale((value) => (value === "zh" ? "en" : "zh"))}><GlobeIcon /><span><strong>{txt("界面语言", "Interface language")}</strong><small>{locale === "zh" ? "简体中文" : "English"}</small></span><b>{locale === "zh" ? "EN" : "中"}</b></button>
              </section>
              <section className="settings-section">
                <h2>{txt("资料", "Library")}</h2>
                <div className="privacy-card"><LockClosedIcon /><div><strong>{txt("本地保存", "Private by default")}</strong><p>{txt("原图与照片保存在这个浏览器的 IndexedDB 中；旧版两张票据的 localStorage 底稿不会被删除。", "Images stay in this browser's IndexedDB. The legacy localStorage copy is kept untouched as a fallback.")}</p></div></div>
                <button className="settings-row" type="button" onClick={exportArchive}><DownloadIcon /><span><strong>{txt("导出资料索引", "Export archive index")}</strong><small>{txt("JSON，不含图片原件", "JSON, without image binaries")}</small></span><ChevronRightIcon /></button>
              </section>
              <section className="plus-card">
                <span className="plus-badge">STUB+</span>
                <h2>{txt("持续服务，才适合订阅", "Subscribe only for ongoing value")}</h2>
                <p>{txt("未来可为云同步、OCR 自动补全、电影/航班信息额度、年度回顾与高级旅册模板付费；本地手动收藏保持免费。", "Future paid value can cover cloud sync, OCR and enrichment credits, annual recaps and premium trip-book templates. Local manual collecting stays free.")}</p>
                <button type="button" onClick={() => setPlusOpen(true)}>{txt("查看盈利方案", "View business model")}<ChevronRightIcon /></button>
              </section>
            </main>
          </MobileScroll>
          <BottomNav active="profile" locale={locale} onNavigate={navigateMain} onAdd={() => navigate("import")} />
        </>
      ) : null}

      {page === "import" ? (
        <MobileScroll key="import" className="app-screen stub-scroll">
          <main className="subpage import-page" data-testid="import-screen">
            <ScreenHeader title={txt("留下一张", "Add a stub")} onBack={() => navigateMain(activeTab)} />
            <section className="import-hero">
              <span className="import-icon" aria-hidden="true"><CameraIcon width={34} height={34} /></span>
              <h2>{txt("把真实票据放进生活存根", "Place a real ticket in Stub")}</h2>
              <p>{txt("拍下电影票、登机牌、车票或小票。下一步可以补标签、专属字段和生活照片。", "Photograph a ticket or receipt, then add tags, category details and memory photos.")}</p>
            </section>
            <div className="import-actions">
              <button type="button" className="primary-cta import-action" onClick={() => cameraInput.current?.click()} disabled={busy} data-testid="camera-upload-button"><CameraIcon width={20} height={20} />{busy ? txt("正在处理…", "Processing…") : txt("拍摄票据", "Take a photo")}</button>
              <button type="button" className="secondary-action" onClick={() => libraryInput.current?.click()} disabled={busy} data-testid="library-upload-button"><ImageIcon width={20} height={20} />{txt("从相册选择", "Choose from library")}</button>
            </div>
            {error ? <p className="form-error" role="alert">{error}</p> : null}
            <div className="privacy-strip"><LockClosedIcon /><span>{txt("Demo 只做本地压缩与保存，不会上传服务器。", "This demo compresses and stores locally. Nothing is uploaded.")}</span></div>
            <input ref={cameraInput} className="visually-hidden" type="file" accept="image/*" capture="environment" onChange={(event) => void handlePrimaryFile(event.target.files?.[0])} data-testid="camera-file-input" />
            <input ref={libraryInput} className="visually-hidden" type="file" accept="image/*" onChange={(event) => void handlePrimaryFile(event.target.files?.[0])} data-testid="library-file-input" />
          </main>
        </MobileScroll>
      ) : null}

      {page === "review" && draft.primary ? (
        <MobileScroll key="review" className="app-screen stub-scroll">
          <main className="subpage review-page" data-testid="review-screen">
            <ScreenHeader title={draft.editingId ? txt("编辑这张存根", "Edit this stub") : txt("补上这一天", "Complete this memory")} onBack={cancelDraft} />
            <img className="review-image" src={draft.primary.preview} alt={txt("待保存的票据预览", "Ticket preview")} draggable={false} />
            <p className="review-hint">{txt("票据已经留好，再补上以后想找回的线索。", "The ticket is safe. Add the clues you will want later.")}</p>
            <div className="stub-form">
              <label className="form-field"><span>{txt("标题", "Title")}</span><KeyboardInput value={draft.title} onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("例如：深夜场电影票", "e.g. Late-night movie") } data-testid="title-input" /></label>
              <label className="form-field"><span>{txt("日期", "Date")}</span><KeyboardInput type="date" value={draft.date} onChange={(event) => setDraft((current) => ({ ...current, date: event.target.value }))} onBlur={() => keyboard.hide()} data-testid="date-input" /></label>
              <fieldset className="type-field"><legend>{txt("类型", "Category")}</legend><div className="type-options">{categoryIds.map((category) => <button type="button" key={category} className={draft.category === category ? "type-chip selected" : "type-chip"} onPointerDown={() => keyboard.hide()} onClick={() => setDraft((current) => ({ ...current, category, subtype: category === "travel" ? (current.subtype === "unknown" ? "flight" : current.subtype) : "unknown" }))}>{categoryLabel(category, locale)}</button>)}</div></fieldset>

              {draft.category === "movie" ? (
                <section className="dynamic-fields">
                  <div className="form-section-title"><MagicWandIcon /><div><strong>{txt("电影信息", "Movie details")}</strong><small>{txt("制式用系统标签保存，方便以后筛选。", "Formats use stable system tags for reliable filtering.")}</small></div></div>
                  <fieldset className="type-field"><legend>{txt("放映制式", "Format")}</legend><div className="type-options">{movieFormats.map((format) => <button type="button" key={format} className={draft.movieFormats.includes(format) ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, movieFormats: current.movieFormats.includes(format) ? current.movieFormats.filter((value) => value !== format) : [...current.movieFormats, format] }))}>{movieFormatLabel(format)}</button>)}</div></fieldset>
                  <label className="form-field"><span>{txt("影院", "Cinema")}</span><KeyboardInput value={draft.movieCinema} onChange={(event) => setDraft((current) => ({ ...current, movieCinema: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="CGV" /></label>
                  <div className="field-pair"><label className="form-field"><span>{txt("影厅", "Hall")}</span><KeyboardInput value={draft.movieHall} onChange={(event) => setDraft((current) => ({ ...current, movieHall: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("6号厅", "Hall 6")} /></label><label className="form-field"><span>{txt("座位", "Seat")}</span><KeyboardInput value={draft.movieSeat} onChange={(event) => setDraft((current) => ({ ...current, movieSeat: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="E07" /></label></div>
                  {draft.poster || posterCandidate ? (
                    <div className={draft.poster || draft.useSuggestedPoster ? "poster-match selected" : "poster-match"}>
                      <img src={draft.poster?.preview || posterCandidate?.src} alt={draft.poster ? txt("用户上传的电影海报", "User-uploaded movie poster") : txt("电影海报候选", "Poster candidate")} draggable={false} />
                      <div><small>{draft.poster ? <ImageIcon /> : <MagicWandIcon />}{draft.poster ? txt("手动封面", "Manual cover") : txt("本地片名匹配候选", "Offline title match")}</small><strong>{draft.poster ? draft.poster.name : locale === "zh" ? posterCandidate?.titleZh : posterCandidate?.titleEn}</strong><p>{draft.poster ? txt("这张海报只保存在当前浏览器。", "This poster stays in this browser.") : txt("Demo 只在内置片库命中片名时给出候选；未命中绝不套用错误海报。正式版再通过后端搜索并让你确认。", "The demo suggests a poster only when its offline catalog matches the title; it never applies an unrelated poster. Production search would run through a backend and require confirmation.")}</p><div>{posterCandidate ? <button type="button" onClick={toggleSuggestedPoster}>{!draft.poster && draft.useSuggestedPoster ? <CheckIcon /> : null}{draft.poster ? txt("改用候选", "Use match") : draft.useSuggestedPoster ? txt("已使用候选", "Match selected") : txt("使用候选", "Use match")}</button> : null}<button type="button" onClick={() => posterInput.current?.click()}>{draft.poster ? txt("更换海报", "Replace poster") : txt("上传海报", "Upload poster")}</button></div></div>
                    </div>
                  ) : (
                    <div className="poster-no-match" role="note"><MagicWandIcon /><div><strong>{txt("暂未找到可靠候选", "No reliable match yet")}</strong><p>{txt("当前 Demo 不会用相似片名冒充匹配。你可以继续保存票根，或手动上传海报。", "The demo will not guess from a vaguely similar title. Keep the ticket as-is or upload a poster manually.")}</p><button type="button" onClick={() => posterInput.current?.click()}>{txt("上传海报", "Upload poster")}</button></div></div>
                  )}
                  <input ref={posterInput} className="visually-hidden" type="file" accept="image/*" onChange={(event) => void handlePosterFile(event.target.files?.[0])} />
                </section>
              ) : null}

              {draft.category === "travel" ? (
                <section className="dynamic-fields">
                  <fieldset className="type-field"><legend>{txt("旅行票据", "Travel type")}</legend><div className="type-options"><button type="button" className={draft.subtype === "flight" ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, subtype: "flight" }))}>{txt("机票", "Flight")}</button><button type="button" className={draft.subtype === "train" ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, subtype: "train" }))}>{txt("车票", "Train")}</button></div></fieldset>
                  {draft.subtype === "flight" ? (
                    <>
                      <div className="form-section-title"><PaperPlaneIcon /><div><strong>{txt("航班信息", "Flight details")}</strong><small>{txt("填写后会生成 Flighty 感的静态行程卡。", "Your fields generate a Flighty-inspired static card.")}</small></div></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("航司", "Airline")}</span><KeyboardInput value={draft.airline} onChange={(event) => setDraft((current) => ({ ...current, airline: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("中国东方航空", "China Eastern")} /></label><label className="form-field"><span>{txt("二字码", "IATA code")}</span><KeyboardInput value={draft.airlineCode} onChange={(event) => setDraft((current) => ({ ...current, airlineCode: event.target.value.slice(0, 2) }))} onBlur={() => keyboard.hide()} placeholder="MU" /></label></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("航班号", "Flight no.")}</span><KeyboardInput value={draft.flightNumber} onChange={(event) => setDraft((current) => ({ ...current, flightNumber: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="MU5237" /></label><label className="form-field"><span>{txt("机型", "Aircraft")}</span><KeyboardInput value={draft.aircraft} onChange={(event) => setDraft((current) => ({ ...current, aircraft: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="A320neo" /></label></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("出发", "From")}</span><KeyboardInput value={draft.departure} onChange={(event) => setDraft((current) => ({ ...current, departure: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="SHA" /></label><label className="form-field"><span>{txt("到达", "To")}</span><KeyboardInput value={draft.arrival} onChange={(event) => setDraft((current) => ({ ...current, arrival: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="CTS" /></label></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("起飞时间", "Departure")}</span><KeyboardInput value={draft.departureTime} onChange={(event) => setDraft((current) => ({ ...current, departureTime: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="08:25" /></label><label className="form-field"><span>{txt("到达时间", "Arrival")}</span><KeyboardInput value={draft.arrivalTime} onChange={(event) => setDraft((current) => ({ ...current, arrivalTime: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="13:05" /></label></div>
                      <fieldset className="type-field"><legend>{txt("舱位", "Cabin")}</legend><div className="type-options">{["economy", "premium", "business", "first"].map((value) => <button type="button" key={value} className={draft.cabin === value ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, cabin: value }))}>{cabinLabel(value, locale)}</button>)}</div></fieldset>
                      <label className="form-field"><span>{txt("座位", "Seat")}</span><KeyboardInput value={draft.flightSeat} onChange={(event) => setDraft((current) => ({ ...current, flightSeat: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="12A" /></label>
                      <FlightCard locale={locale} details={{ kind: "flight", airline: draft.airline, airlineCode: draft.airlineCode, flightNumber: draft.flightNumber, aircraft: draft.aircraft, cabin: draft.cabin, seat: draft.flightSeat, departure: draft.departure, arrival: draft.arrival, departureTime: draft.departureTime, arrivalTime: draft.arrivalTime }} />
                    </>
                  ) : draft.subtype === "train" ? (
                    <>
                      <div className="form-section-title"><ReaderIcon /><div><strong>{txt("车票信息", "Train details")}</strong><small>{txt("车次、席别、车厢与座位分开保存。", "Train, class, coach and seat are stored separately.")}</small></div></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("运营方", "Operator")}</span><KeyboardInput value={draft.trainOperator} onChange={(event) => setDraft((current) => ({ ...current, trainOperator: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("中国铁路", "China Railway")} /></label><label className="form-field"><span>{txt("车次", "Train no.")}</span><KeyboardInput value={draft.trainNumber} onChange={(event) => setDraft((current) => ({ ...current, trainNumber: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="G7501" /></label></div>
                      <div className="field-pair"><label className="form-field"><span>{txt("出发站", "From")}</span><KeyboardInput value={draft.departure} onChange={(event) => setDraft((current) => ({ ...current, departure: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("杭州东", "Hangzhoudong")} /></label><label className="form-field"><span>{txt("到达站", "To")}</span><KeyboardInput value={draft.arrival} onChange={(event) => setDraft((current) => ({ ...current, arrival: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("苏州", "Suzhou")} /></label></div>
                      <fieldset className="type-field"><legend>{txt("席别", "Seat class")}</legend><div className="type-options">{["second", "first", "business", "sleeper"].map((value) => <button type="button" key={value} className={draft.trainClass === value ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, trainClass: value }))}>{trainClassLabel(value, locale)}</button>)}</div></fieldset>
                      <div className="field-pair"><label className="form-field"><span>{txt("车厢", "Coach")}</span><KeyboardInput value={draft.trainCoach} onChange={(event) => setDraft((current) => ({ ...current, trainCoach: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="02" /></label><label className="form-field"><span>{txt("座位", "Seat")}</span><KeyboardInput value={draft.trainSeat} onChange={(event) => setDraft((current) => ({ ...current, trainSeat: event.target.value }))} onBlur={() => keyboard.hide()} placeholder="08A" /></label></div>
                    </>
                  ) : (
                    <div className="travel-type-prompt" role="note">
                      <ReaderIcon />
                      <div><strong>{txt("先确认这是什么票", "Choose the travel type")}</strong><p>{txt("旧版导入不会猜测机票或车票，选定后再补充专属信息。", "Legacy imports are never guessed. Choose Flight or Train before adding its specific details.")}</p></div>
                    </div>
                  )}
                  <fieldset className="type-field"><legend>{txt("收进旅册（可选）", "Add to a trip book (optional)")}</legend><div className="type-options"><button type="button" className={!draft.tripId ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, tripId: "" }))}>{txt("暂不收录", "Not now")}</button>{allTrips.map((trip) => <button type="button" key={trip.id} className={draft.tripId === trip.id ? "type-chip selected" : "type-chip"} onClick={() => setDraft((current) => ({ ...current, tripId: trip.id }))}>{tripTitle(trip, locale)}</button>)}</div></fieldset>
                </section>
              ) : null}

              {draft.category !== "movie" && draft.category !== "travel" ? <label className="form-field"><span>{txt("地点", "Location")}</span><KeyboardInput value={draft.location} onChange={(event) => setDraft((current) => ({ ...current, location: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("例如：札幌 · 狸小路", "e.g. Sapporo · Tanukikoji")} /></label> : null}

              <section className="tag-editor">
                <div className="form-section-title"><ArchiveIcon /><div><strong>{txt("生活标签", "Personal tags")}</strong><small>{txt("和电影制式分开，按你自己的方式记。", "Separate from system formats, written your way.")}</small></div></div>
                <div className="type-options">{suggestedTags.map((tag) => <button type="button" key={tag.id} className={draft.tags.includes(tag.id) ? "type-chip selected" : "type-chip"} onClick={() => toggleDraftTag(tag.id)}>{locale === "zh" ? tag.zh : tag.en}</button>)}</div>
                <div className="tag-input-row"><KeyboardInput value={draft.tagInput} onChange={(event) => setDraft((current) => ({ ...current, tagInput: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("自定义标签", "Custom tag")} /><button type="button" onClick={addCustomTag}><PlusIcon />{txt("添加", "Add")}</button></div>
              </section>

              <section className="attachment-editor">
                <div className="form-section-title"><ImageIcon /><div><strong>{txt("当时的照片", "Memory photos")}</strong><small>{txt("最多 6 张，例如食物、同行的人或街景。", "Up to 6 photos: food, companions or the street outside.")}</small></div></div>
                {draft.attachments.length ? <Carousel ariaLabel={txt("已选照片", "Selected photos")} className="attachment-carousel" contentClassName="attachment-track">{draft.attachments.map((asset) => <figure key={asset.id}><img src={asset.preview} alt={asset.name} draggable={false} /><button type="button" onClick={() => { if (asset.ownsPreview) URL.revokeObjectURL(asset.preview); setDraft((current) => ({ ...current, attachments: current.attachments.filter((item) => item.id !== asset.id) })); }} aria-label={txt("移除照片", "Remove photo")}><Cross2Icon /></button></figure>)}</Carousel> : null}
                <button type="button" className="add-photo-button" onClick={() => attachmentInput.current?.click()} disabled={busy || draft.attachments.length >= 6}><ImageIcon />{txt("添加生活照片", "Add memory photos")}</button>
                <input ref={attachmentInput} className="visually-hidden" type="file" accept="image/*" multiple onChange={(event) => void handleAttachments(event.target.files)} />
              </section>

              <label className="form-field"><span>{txt("想记住的一句话", "A line to remember")}</span><KeyboardTextarea value={draft.note} onChange={(event) => setDraft((current) => ({ ...current, note: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("那天发生了什么？", "What happened that day?")} rows={3} data-testid="note-input" /></label>
            </div>
            {error ? <p className="form-error" role="alert">{error}</p> : null}
            <button className="primary-cta save-button" type="button" onPointerDown={() => keyboard.hide()} onClick={() => void saveDraft()} disabled={busy} data-testid="save-button">{busy ? txt("正在保存…", "Saving…") : draft.editingId ? txt("保存更改", "Save changes") : txt("保存这张存根", "Save this stub")}</button>
          </main>
        </MobileScroll>
      ) : null}

      {page === "detail" && selectedRecord ? (
        <MobileScroll key="detail" className="app-screen stub-scroll">
          <main className="subpage detail-page" data-testid="detail-screen">
            <ScreenHeader title={txt("一张存根", "A stub")} onBack={() => navigateMain(returnTab)} action={<button className="icon-button plain" type="button" onClick={() => setTripPickerOpen(true)} aria-label={txt("存根操作", "Stub actions")}><DotsHorizontalIcon /></button>} />
            {selectedRecord.details.kind === "movie" && selectedRecord.posterMediaId ? (
              <section className="movie-detail-hero"><img src={mediaUrl(selectedRecord.posterMediaId)} alt={recordTitle(selectedRecord, locale)} draggable={false} /><div><small>{selectedRecord.details.formatIds.map(movieFormatLabel).join(" · ") || txt("电影", "MOVIE")}</small><h2>{recordTitle(selectedRecord, locale)}</h2><p>{selectedRecord.details.cinema}</p><span>{selectedRecord.details.hall}{selectedRecord.details.seat ? ` · ${selectedRecord.details.seat}` : ""}</span></div></section>
            ) : null}
            {selectedRecord.details.kind === "flight" ? <FlightCard details={selectedRecord.details} locale={locale} /> : null}
            <img className="detail-image" src={mediaUrl(selectedRecord.primaryMediaId)} alt={recordTitle(selectedRecord, locale)} draggable={false} />
            <div className="detail-copy">
              <div className="detail-label-row"><p className="detail-type">{categoryLabel(selectedRecord.category, locale)}{selectedRecord.subtype ? ` · ${selectedRecord.subtype === "flight" ? txt("机票", "Flight") : selectedRecord.subtype === "train" ? txt("车票", "Train") : txt("旅行", "Travel")}` : ""}</p><time dateTime={selectedRecord.occurredOn}>{formatDate(selectedRecord.occurredOn, locale)}</time></div>
              {selectedRecord.details.kind !== "movie" ? <h2>{recordTitle(selectedRecord, locale)}</h2> : null}
              <div className="detail-tags">{selectedRecord.details.kind === "movie" ? selectedRecord.details.formatIds.map((format) => <span key={format}>{movieFormatLabel(format)}</span>) : null}{selectedRecord.tags.map((tag) => <span key={tag}>{tagLabel(tag, locale)}</span>)}</div>
              <p className="detail-note">{recordNote(selectedRecord, locale) || txt("这一张，替你记住了那一天。", "This one remembers the day for you.")}</p>
            </div>
            {selectedRecord.attachmentIds.length ? <section className="detail-attachments"><h3>{txt("当时的照片", "Photos from then")}</h3><Carousel ariaLabel={txt("生活照片", "Memory photos")} className="detail-photo-carousel" contentClassName="detail-photo-track">{selectedRecord.attachmentIds.map((id) => <img key={id} src={mediaUrl(id)} alt="" draggable={false} />)}</Carousel></section> : null}
            <section className="canonical-note"><ArchiveIcon /><div><strong>{txt("一份存根，多个视图", "One stub, many views")}</strong><p>{txt("首页、墙和旅册引用的是同一份资料；旅册只保存排版和批注，所以修改不会不同步。", "Home, Wall and Trip Books reference the same record. A book stores only layout and captions, so edits never drift.")}</p></div></section>
            <div className="detail-actions">{selectedRecord.source === "user" ? <button className="secondary-action" type="button" onClick={() => startEditing(selectedRecord)}><Pencil2Icon />{txt("编辑标签与信息", "Edit tags and details")}</button> : null}<button className="secondary-action" type="button" onClick={() => setTripPickerOpen(true)}><ReaderIcon />{txt("收进旅册", "Add to trip book")}</button>{selectedRecord.source === "user" ? <button className="delete-button" type="button" onClick={() => void removeSelected()}><TrashIcon />{txt("移除这张存根", "Remove this stub")}</button> : null}</div>
          </main>
        </MobileScroll>
      ) : null}

      {page === "tripBook" ? (
        <MobileScroll key="trip-book" className="app-screen stub-scroll">
          <main className="subpage trip-book-page" data-testid="trip-book-screen">
            <ScreenHeader title={txt("一本旅册", "Trip book")} onBack={() => navigateMain("trips")} />
            <section className="trip-book-cover">
              <img src="/stub-assets/trip-map-hokkaido.png" alt="" draggable={false} />
              <div><small>STUB · TRIP BOOK</small><h1>{tripTitle(selectedTrip, locale)}</h1><p>{locale === "en" && selectedTrip.routeEn ? selectedTrip.routeEn : selectedTrip.route}</p><time>{formatDate(selectedTrip.startDate, locale)}—{formatDate(selectedTrip.endDate, locale)}</time><blockquote>{selectedTrip.note || txt("把散落在路上的纸片，装订成一次旅行。", "Bind the paper left along the way into one journey.")}</blockquote></div>
            </section>
            {selectedTripRecords.length ? (
              <section className="book-pages">
                {selectedTripRecords.map(({ item, record }) => (
                  <article className="book-page" key={item.id}>
                    <div className="book-day"><span>DAY {String(item.day).padStart(2, "0")}</span><time>{formatDate(record.occurredOn, locale)}</time></div>
                    {record.details.kind === "flight" ? <FlightCard details={record.details} locale={locale} /> : null}
                    <button className="book-artifact" type="button" onClick={() => openDetail(record.id, "trips")} style={{ transform: `rotate(${item.rotation}deg) scale(${item.scale})` }}>
                      <img src={mediaUrl(record.primaryMediaId)} alt={recordTitle(record, locale)} draggable={false} />
                    </button>
                    <div className="book-caption"><small>{item.caption || categoryLabel(record.category, locale)}</small><h2>{recordTitle(record, locale)}</h2><p>{recordNote(record, locale)}</p><button type="button" onClick={() => openDetail(record.id, "trips")}>{txt("查看原存根", "View canonical stub")}<ChevronRightIcon /></button></div>
                  </article>
                ))}
              </section>
            ) : (
              <section className="empty-book"><ReaderIcon /><h2>{txt("这本旅册还没有纸片", "This trip book is still empty")}</h2><p>{txt("打开任意存根，选择“收进旅册”。它仍会保留在首页和存根墙。", "Open any stub and choose “Add to trip book”. It will stay on Home and Wall.")}</p><button type="button" onClick={() => navigateMain("home")}>{txt("去首页挑一张", "Choose from Home")}</button></section>
            )}
          </main>
        </MobileScroll>
      ) : null}

      <BottomSheet open={filterOpen} onOpenChange={setFilterOpen} title={txt("筛选存根", "Filter stubs")} description={txt("类型和标签可以组合筛选。", "Combine a category with a personal tag.")}>
        <div className="filter-sheet"><fieldset className="type-field"><legend>{txt("类型", "Category")}</legend><div className="type-options">{["all", ...categoryIds].map((value) => <button type="button" key={value} className={filter === value ? "type-chip selected" : "type-chip"} onClick={() => setFilter(value as CategoryId | "all")}>{value === "all" ? txt("全部", "All") : categoryLabel(value as CategoryId, locale)}</button>)}</div></fieldset>{availableTags.length ? <fieldset className="type-field"><legend>{txt("标签", "Tag")}</legend><div className="type-options"><button type="button" className={tagFilter === "all" ? "type-chip selected" : "type-chip"} onClick={() => setTagFilter("all")}>{txt("全部标签", "All tags")}</button>{availableTags.map((tag) => <button type="button" key={tag} className={tagFilter === tag ? "type-chip selected" : "type-chip"} onClick={() => setTagFilter(tag)}>{tagLabel(tag, locale)}</button>)}</div></fieldset> : null}<button className="primary-cta filter-apply" type="button" onClick={() => setFilterOpen(false)}>{txt("查看结果", "Show results")}</button></div>
      </BottomSheet>

      <BottomSheet open={tripPickerOpen} onOpenChange={setTripPickerOpen} title={txt("收进旅册", "Add to trip book")} description={txt("这是引用，不会复制或移动原存根。", "This is a reference; the original is neither copied nor moved.")}>
        <div className="trip-picker">{allTrips.map((trip) => { const present = selectedRecord ? allTripItems.some((item) => item.tripId === trip.id && item.stubId === selectedRecord.id) : false; return <button type="button" key={trip.id} onClick={() => void addSelectedToTrip(trip.id)}><ReaderIcon /><span><strong>{tripTitle(trip, locale)}</strong><small>{locale === "en" && trip.routeEn ? trip.routeEn : trip.route}</small></span>{present ? <CheckCircledIcon /> : <ChevronRightIcon />}</button>; })}<button type="button" className="trip-picker-new" onClick={() => { setTripPickerOpen(false); setTripCreateOpen(true); }}><PlusIcon />{txt("新建旅册", "New trip book")}</button></div>
      </BottomSheet>

      <BottomSheet open={tripCreateOpen} onOpenChange={setTripCreateOpen} title={txt("新建旅册", "New trip book")} description={txt("一次旅行，一本可以慢慢补完的书。", "One journey, one book you can keep completing.")}>
        <div className="sheet-form"><label className="form-field"><span>{txt("旅册标题", "Title")}</span><KeyboardInput value={newTrip.title} onChange={(event) => setNewTrip((current) => ({ ...current, title: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("例如：京都 · 2026 秋", "e.g. Kyoto · Autumn 2026")} /></label><div className="field-pair"><label className="form-field"><span>{txt("开始", "Start")}</span><KeyboardInput type="date" value={newTrip.startDate} onChange={(event) => setNewTrip((current) => ({ ...current, startDate: event.target.value }))} onBlur={() => keyboard.hide()} /></label><label className="form-field"><span>{txt("结束", "End")}</span><KeyboardInput type="date" value={newTrip.endDate} onChange={(event) => setNewTrip((current) => ({ ...current, endDate: event.target.value }))} onBlur={() => keyboard.hide()} /></label></div><label className="form-field"><span>{txt("路线", "Route")}</span><KeyboardInput value={newTrip.route} onChange={(event) => setNewTrip((current) => ({ ...current, route: event.target.value }))} onBlur={() => keyboard.hide()} placeholder={txt("上海—京都—大阪", "Shanghai—Kyoto—Osaka")} /></label><label className="form-field"><span>{txt("封面一句话", "Cover note")}</span><KeyboardTextarea value={newTrip.note} onChange={(event) => setNewTrip((current) => ({ ...current, note: event.target.value }))} onBlur={() => keyboard.hide()} rows={2} placeholder={txt("想怎样记住这趟旅行？", "How do you want to remember it?")} /></label><button type="button" className="primary-cta" onClick={() => void createTrip()}>{txt("放上书架", "Put on shelf")}</button></div>
      </BottomSheet>

      <BottomSheet open={plusOpen} onOpenChange={setPlusOpen} title="Stub+" description={txt("盈利不应该破坏私人记忆库的信任。", "Revenue should never compromise a private memory archive.")}>
        <div className="business-sheet"><section><strong>{txt("免费本地收藏", "Free local collecting")}</strong><p>{txt("手动上传、标签、基础旅册和本地存根数量不设人为上限。", "Manual uploads, tags, basic trip books and local stub counts stay unrestricted.")}</p></section><section><strong>{txt("订阅持续服务", "Subscription for ongoing services")}</strong><p>{txt("云备份与跨设备同步、OCR/海报/航班补全额度、高清附件、年度回顾和高级模板。", "Cloud backup and sync, OCR/poster/flight enrichment credits, high-resolution media, annual recaps and premium templates.")}</p></section><section><strong>{txt("一次性与实体收入", "One-time and physical revenue")}</strong><p>{txt("主题或 PDF 导出可买断；旅行册、年度存根墙可印成实体书、折页或明信片。", "Themes or PDF export can be one-time purchases; trip books and annual walls can become printed books, foldouts or postcards.")}</p></section><p className="business-note">{txt("早期不建议广告和售票联盟：它们会把私密收藏变成消费导流。", "Avoid ads and ticket affiliates early: they turn private collecting into a sales funnel.")}</p></div>
      </BottomSheet>

      {toast ? <div className="toast" role="status" data-testid="toast"><CheckIcon width={18} height={18} />{toast}<button type="button" onClick={() => setToast("")} aria-label={txt("关闭提示", "Dismiss")}><Cross2Icon /></button></div> : null}
    </div>
  );
}
