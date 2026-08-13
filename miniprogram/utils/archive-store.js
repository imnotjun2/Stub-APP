const ARCHIVE_KEY = 'stub.archive.v1'
const SCHEMA_VERSION = 1
const SAMPLE_TRIP_ID = 'trip-hokkaido-2026'

function uid(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`
}

function createFixtureArchive() {
  return {
    schemaVersion: SCHEMA_VERSION,
    records: [
      {
        schemaVersion: 1,
        id: 'stub-sample-movie',
        source: 'sample',
        title: '名侦探柯南：百万美元的五棱星',
        occurredOn: '2026-08-10',
        category: 'movie',
        subtype: '',
        note: '和你一起看柯南首映的夜晚，散场时外面还在下雨。',
        tags: ['首映', '雨天'],
        primaryMedia: { location: 'bundled', value: '/assets/movie-poster.jpg' },
        attachments: [],
        posterMedia: { location: 'bundled', value: '/assets/movie-poster.jpg' },
        details: {
          cinema: 'CGV 影城 合生汇店',
          hall: '6号厅',
          seat: 'E07',
          format: 'IMAX',
          location: '上海'
        },
        createdAt: '2026-08-10T19:20:00.000Z',
        updatedAt: '2026-08-10T19:20:00.000Z'
      },
      {
        schemaVersion: 1,
        id: 'stub-sample-flight',
        source: 'sample',
        title: '上海飞札幌',
        occurredOn: '2026-08-03',
        category: 'travel',
        subtype: 'flight',
        note: '靠窗的 12A，云层散开时第一次看见北海道。',
        tags: ['独自出发'],
        primaryMedia: { location: 'bundled', value: '/assets/boarding-pass.jpg' },
        attachments: [],
        posterMedia: null,
        details: {
          number: 'MU5237',
          departure: 'SHA',
          arrival: 'CTS',
          seat: '12A',
          location: '上海 → 札幌'
        },
        createdAt: '2026-08-03T08:25:00.000Z',
        updatedAt: '2026-08-03T08:25:00.000Z'
      },
      {
        schemaVersion: 1,
        id: 'stub-sample-food',
        source: 'sample',
        title: '札幌雨夜的味噌拉面',
        occurredOn: '2026-08-04',
        category: 'food',
        subtype: '',
        note: '雨停以后沿着狸小路慢慢走，热汤刚好。',
        tags: ['好吃', '雨天'],
        primaryMedia: { location: 'bundled', value: '/assets/ramen.jpg' },
        attachments: [],
        posterMedia: null,
        details: {
          location: '札幌 · 狸小路'
        },
        createdAt: '2026-08-04T12:00:00.000Z',
        updatedAt: '2026-08-04T12:00:00.000Z'
      }
    ],
    trips: [
      {
        id: SAMPLE_TRIP_ID,
        source: 'sample',
        title: '札幌 · 2026 夏',
        startDate: '2026-08-03',
        endDate: '2026-08-10',
        route: '上海 → 札幌 → 小樽 → 旭川',
        note: '雨落在北海道的八月。',
        cover: '/assets/trip-map.jpg'
      }
    ],
    placements: [
      { id: 'placement-flight', tripId: SAMPLE_TRIP_ID, stubId: 'stub-sample-flight', day: 1, order: 1 },
      { id: 'placement-food', tripId: SAMPLE_TRIP_ID, stubId: 'stub-sample-food', day: 2, order: 2 }
    ]
  }
}

function normalizeArchive(value) {
  if (!value || typeof value !== 'object') return createFixtureArchive()
  const records = Array.isArray(value.records) ? value.records.map((record) => {
    if (
      record.id === 'stub-sample-food' &&
      (!Array.isArray(record.attachments) || record.attachments.length === 0) &&
      record.primaryMedia
    ) {
      return { ...record, attachments: [{ ...record.primaryMedia }] }
    }
    return record
  }) : []
  return {
    schemaVersion: SCHEMA_VERSION,
    records,
    trips: Array.isArray(value.trips) ? value.trips : [],
    placements: Array.isArray(value.placements) ? value.placements : []
  }
}

function ensureArchive() {
  try {
    const existing = wx.getStorageSync(ARCHIVE_KEY)
    if (existing && Array.isArray(existing.records)) return normalizeArchive(existing)
  } catch (error) {
    console.warn('Stub archive read failed', error)
  }

  const archive = createFixtureArchive()
  wx.setStorageSync(ARCHIVE_KEY, archive)
  return archive
}

function getArchive() {
  return normalizeArchive(ensureArchive())
}

function saveArchive(archive) {
  const normalized = normalizeArchive(archive)
  wx.setStorageSync(ARCHIVE_KEY, normalized)
  return normalized
}

function listRecords() {
  return getArchive().records.slice().sort((a, b) => b.occurredOn.localeCompare(a.occurredOn))
}

function getRecord(id) {
  return getArchive().records.find((record) => record.id === id) || null
}

function getTrip(id) {
  return getArchive().trips.find((trip) => trip.id === id) || null
}

function recordsForTrip(tripId) {
  const archive = getArchive()
  const recordsById = archive.records.reduce((result, record) => {
    result[record.id] = record
    return result
  }, {})
  return archive.placements
    .filter((placement) => placement.tripId === tripId)
    .sort((a, b) => a.order - b.order)
    .map((placement) => ({ placement, record: recordsById[placement.stubId] }))
    .filter((item) => item.record)
}

function dayForRecord(record, trip) {
  if (!record || !trip || !record.occurredOn || !trip.startDate) return 1
  const occurredAt = Date.parse(`${record.occurredOn}T00:00:00Z`)
  const tripStartedAt = Date.parse(`${trip.startDate}T00:00:00Z`)
  if (!Number.isFinite(occurredAt) || !Number.isFinite(tripStartedAt)) return 1
  return Math.max(1, Math.floor((occurredAt - tripStartedAt) / 86400000) + 1)
}

function upsertRecord(record, tripId) {
  const archive = getArchive()
  const previousPlacement = archive.placements.find((item) => item.stubId === record.id) || null
  const index = archive.records.findIndex((item) => item.id === record.id)
  if (index >= 0) {
    const previous = archive.records[index]
    if (
      previous.primaryMedia &&
      previous.primaryMedia.location === 'local' &&
      record.primaryMedia &&
      previous.primaryMedia.value !== record.primaryMedia.value
    ) {
      deleteLocalMedia(previous.primaryMedia)
    }
    archive.records[index] = record
  }
  else archive.records.push(record)

  archive.placements = archive.placements.filter((item) => item.stubId !== record.id)
  if (tripId) {
    const sameTrip = previousPlacement && previousPlacement.tripId === tripId
    const trip = archive.trips.find((item) => item.id === tripId)
    const nextOrder = sameTrip
      ? previousPlacement.order
      : archive.placements.filter((item) => item.tripId === tripId).length + 1
    archive.placements.push({
      id: sameTrip ? previousPlacement.id : uid('placement'),
      tripId,
      stubId: record.id,
      day: sameTrip ? previousPlacement.day : dayForRecord(record, trip),
      order: nextOrder
    })
  }
  saveArchive(archive)
  return record
}

function deleteLocalMedia(reference) {
  if (!reference || reference.location !== 'local' || !reference.value) return
  wx.getFileSystemManager().unlink({
    filePath: reference.value,
    fail: () => {}
  })
}

function deleteRecord(id) {
  const archive = getArchive()
  const record = archive.records.find((item) => item.id === id)
  if (!record || record.source !== 'user') return false
  deleteLocalMedia(record.primaryMedia)
  ;(record.attachments || []).forEach(deleteLocalMedia)
  deleteLocalMedia(record.posterMedia)
  archive.records = archive.records.filter((item) => item.id !== id)
  archive.placements = archive.placements.filter((item) => item.stubId !== id)
  saveArchive(archive)
  return true
}

function resetArchive() {
  const current = getArchive()
  current.records.filter((record) => record.source === 'user').forEach((record) => {
    deleteLocalMedia(record.primaryMedia)
    ;(record.attachments || []).forEach(deleteLocalMedia)
    deleteLocalMedia(record.posterMedia)
  })
  const next = createFixtureArchive()
  saveArchive(next)
  return next
}

function saveTicketFile(tempFilePath) {
  if (!tempFilePath) return Promise.reject(new Error('没有可保存的票据图片'))
  if (tempFilePath.startsWith(wx.env.USER_DATA_PATH)) return Promise.resolve(tempFilePath)

  const extensionMatch = tempFilePath.match(/\.([a-zA-Z0-9]+)(?:\?|$)/)
  const extension = extensionMatch ? extensionMatch[1].toLowerCase() : 'jpg'
  const destination = `${wx.env.USER_DATA_PATH}/${uid('stub-ticket')}.${extension}`

  return new Promise((resolve, reject) => {
    wx.getFileSystemManager().copyFile({
      srcPath: tempFilePath,
      destPath: destination,
      success: () => resolve(destination),
      fail: (error) => reject(new Error(error.errMsg || '票据图片保存失败'))
    })
  })
}

module.exports = {
  ARCHIVE_KEY,
  SAMPLE_TRIP_ID,
  uid,
  ensureArchive,
  getArchive,
  saveArchive,
  listRecords,
  getRecord,
  getTrip,
  recordsForTrip,
  upsertRecord,
  deleteRecord,
  resetArchive,
  saveTicketFile
}
