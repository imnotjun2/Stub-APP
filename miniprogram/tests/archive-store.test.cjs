const assert = require('node:assert/strict')

const storage = new Map()
const copiedFiles = []
const deletedFiles = []

global.wx = {
  env: { USER_DATA_PATH: '/mock-user-data' },
  getStorageSync(key) {
    return storage.get(key)
  },
  setStorageSync(key, value) {
    storage.set(key, JSON.parse(JSON.stringify(value)))
  },
  getFileSystemManager() {
    return {
      copyFile({ srcPath, destPath, success }) {
        copiedFiles.push({ srcPath, destPath })
        success()
      },
      unlink({ filePath }) {
        deletedFiles.push(filePath)
      }
    }
  }
}

async function main() {
  const store = require('../utils/archive-store')
  const { recordViewModel } = require('../utils/presentation')
  const initial = store.ensureArchive()
  assert.equal(initial.records.length, 3)
  assert.equal(initial.trips.length, 1)
  assert.equal(store.recordsForTrip(store.SAMPLE_TRIP_ID).length, 2)
  assert.equal(store.getRecord('stub-sample-food').attachments.length, 1)
  assert.equal(recordViewModel(store.getRecord('stub-sample-movie')).coverMode, 'aspectFill')
  assert.equal(recordViewModel(store.getRecord('stub-sample-flight')).coverMode, 'aspectFit')
  assert.equal(recordViewModel(store.getRecord('stub-sample-food')).coverMode, 'aspectFill')

  const savedPath = await store.saveTicketFile('/tmp/my-ticket.jpg')
  assert.match(savedPath, /^\/mock-user-data\/stub-ticket-/)
  assert.equal(copiedFiles.length, 1)

  const record = {
    id: 'stub-user-test',
    source: 'user',
    title: '真实电影票',
    occurredOn: '2026-08-11',
    category: 'movie',
    subtype: '',
    note: '测试本地保存',
    tags: ['首映'],
    primaryMedia: { location: 'local', value: savedPath },
    attachments: [],
    posterMedia: null,
    details: { cinema: '测试影院' },
    createdAt: '2026-08-11T00:00:00.000Z',
    updatedAt: '2026-08-11T00:00:00.000Z'
  }

  store.upsertRecord(record, store.SAMPLE_TRIP_ID)
  assert.equal(store.getRecord(record.id).title, '真实电影票')
  assert.equal(store.listRecords().filter((item) => item.id === record.id).length, 1)
  assert.equal(store.recordsForTrip(store.SAMPLE_TRIP_ID).filter((item) => item.record.id === record.id).length, 1)

  const placementBeforeEdit = store.getArchive().placements.find((item) => item.stubId === record.id)
  store.upsertRecord({ ...record, title: '编辑后的真实电影票' }, store.SAMPLE_TRIP_ID)
  const placementAfterEdit = store.getArchive().placements.find((item) => item.stubId === record.id)
  assert.equal(placementAfterEdit.id, placementBeforeEdit.id)
  assert.equal(placementAfterEdit.order, placementBeforeEdit.order)
  assert.equal(placementAfterEdit.day, placementBeforeEdit.day)

  assert.equal(store.deleteRecord(record.id), true)
  assert.equal(store.getRecord(record.id), null)
  assert.ok(deletedFiles.includes(savedPath))

  store.resetArchive()
  assert.equal(store.listRecords().length, 3)
  console.log('ArchiveStore 本地持久化契约通过。')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
